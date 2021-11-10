#!/usr/bin/env python3
"""
A command line utility to manage JCentral replicas.
"""

from pathlib import Path
import logging
import os
import shutil
import signal
import sys

import click
import docker

from subprocess import call

logging.basicConfig(format="%(asctime)s [%(levelname)s] :: %(message)s",
                    datefmt="%Y/%m/%d %H:%M:%S",
                    level=logging.INFO)

DEFAULT_DOCKER_IMAGE = 'jalien-dev'

# pylint: disable=unused-argument
def timeout(signum, frame):
    """
    Timeout handler in case the setup takes too long.
    """
    logging.error("Setup Script taking too long. Check docker logs for more information")
    sys.exit(1)

def workspace_cleanup(certpath, sepath):
    """
    Remove certificates if they already exist in the shared volume.
    """
    logging.info("Deleting old certificate files from %s", certpath)
    shutil.rmtree(certpath, ignore_errors=True)
    certpath.mkdir(parents=True, exist_ok=True)

    logging.info("Please manually delete files from %s to avoid stale files persisting", sepath)
    shutil.rmtree(sepath, ignore_errors=True)
    sepath.mkdir(parents=True, exist_ok=True)
    logging.info("Finished cleanup!")

def params_check(volume, jar):
    """
    Validate command-line parameters (shared volume, jar file)
    """
    xrootd_tkauth = './xrootd/xrootd-conf/TkAuthz.Authorization'
    xrootd_tkauth = Path(xrootd_tkauth).expanduser().absolute()
    if not volume.exists():
        logging.info("Creating the shared volume directory in %s", volume)
        volume.mkdir(parents=True)
    elif volume.is_file():
        logging.error("Shared volume path is a file, not a directory")
        return False

    if jar.is_file():
        shutil.copy(jar, volume)
    else:
        logging.error("JAR file not found in {jar}")
        return False
    logging.info("Sharing the TkAuthz.Authorization in %s", xrootd_tkauth)
    shutil.copy(xrootd_tkauth, volume)

    return True

def get_info(volume):
    """
    Generate the source_env.sh script contents.
    """
    certpath = str(volume.joinpath("certs", "globus"))
    script = ['# Source this script to point JAliEn clients to the replica',
              f'certpath="{certpath}"',
              'export ALIENPY_JCENTRAL="127.0.0.1"',
              'export X509_CERT_DIR="${certpath}/CA"',
              'export CERT=${certpath}/user/usercert.pem',
              'export KEY=${certpath}/user/userkey.pem',
              'export X509_USER_CERT="${CERT}"',
              'export X509_USER_KEY="${KEY}"',
              'export JALIEN_TOKEN_CERT="${CERT}"',
              'export JALIEN_TOKEN_KEY="${KEY}"',
              'export JALIEN_HOST="localhost"',
              'export JALIEN_WSPORT=8097',
              ]

    return '\n'.join(script)

def bootstrap_workspace(volume, jar, cleanup):
    """
    Prepare the shared volume for starting up a new JCentral instance.
    """
    certpath = volume.joinpath("certs")
    sepath = volume.joinpath("SEshared")

    if not params_check(volume, jar):
        logging.error("Can't start the container, exiting...")
        return 1

    if cleanup:
        workspace_cleanup(certpath, sepath)

    script = get_info(volume)
    print(script)

    with open(volume.joinpath('env_setup.sh'), "w+") as file:
        file.write(script)

    return 0

def start_container(jalien_setup_repo, volume, image, replica_name, cmd):
    """
    Start a JCentral replica container
    """
    uid = os.getuid()
    env = ["USER_ID="+str(uid), "SE_HOST="+replica_name+"-SE"]
    se_image = 'xrootd-se'
    se_cmd = 'bash /runner.sh'
    network_name = "localhost"
    client = docker.from_env()

    logging.info("Removing old localhost network (if any)")
    try:
        call("docker network rm localhost", shell=True)
        network = client.networks.list(filters={'name':network_name})[0]
        logging.info("A network with the name %s already exists.", network_name)
        logging.info("Please remove it or specify a different name.")
        sys.exit(1)
    except IndexError:
        logging.info("Network named %s does not exist!", network_name)

    network = client.networks.create("localhost", driver="bridge")

    logging.info("Removing old JCentral and XRootD container (if any)")
    try:
        jalien_container = client.containers.list(filters={'name':replica_name})[0]
        logging.info("A container with the name %s or %s-SE already exists.", replica_name, replica_name)
        logging.info("Please remove it or specify a different name.")
        sys.exit(1)
    except IndexError:
        logging.info("Container named %s does not exist!", replica_name)

    logging.info("command is: %s", cmd)
    jalien_container = client.containers.run(image, cmd,
                                             auto_remove=True,
                                             name=replica_name,
                                             network=network_name,
                                             hostname="localhost.localdomain",
                                             environment=env,
                                             detach=True,
                                             ports={'8098/tcp':'8098', '8097/tcp':'8097', '3307/tcp':'3307', '8389/tcp':'8389'},
                                             volumes={
                                                 str(volume):{'bind':'/jalien-dev', 'mode':'rw'},
                                                 str(jalien_setup_repo):{'bind':'/jalien-setup', 'mode':'rw'},
                                             })
    logging.info("command is: %s", se_cmd)
    xrootd_container = client.containers.run(se_image, se_cmd,
                                             auto_remove=True,
                                             name=replica_name+"-SE",
                                             network=network_name,
                                             detach=True,
                                             ports={'1094/tcp':'1094'},
                                             volumes={
                                                 str(volume):{'bind':'/jalien-dev', 'mode':'rw'},
                                                 "xrootd-se-storage":{'bind':'/shared-volume', 'mode':'rw'}
                                             })

    if jalien_container.status != 'created':
        logging.info("Something went wrong with container. Streaming logs..")
        logging.info(jalien_container.logs())

    if xrootd_container.status != 'created':
        logging.info("Something went wrong with XRootD container. Streaming logs..")
        logging.info(xrootd_container.logs())

    return jalien_container, xrootd_container

def wait_for_service(jalien_container):
    """
    Parse the container logs until JCentral is up and running.
    """
    signal.signal(signal.SIGALRM, timeout)
    signal.alarm(60) #normally never takes longer than 20 seconds

    for i in jalien_container.logs(stream=True):
        print(i.decode().strip('\n'))

        if 'JCentral listening on' in i.decode():
            print("Container is running JCentral")
            break
        elif ':1094 initialization completed' in i.decode():
            print("SE is running")
            break
        elif 'xrootd is terminating' in i.decode():
            print("SE failed... Skipping SE setup")
            break

@click.group()
# pylint: disable=missing-docstring
def jalien_docker():
    pass

@jalien_docker.command()
@click.option('--volume', default="/tmp/jalien-replica", required=True,
              help='The path mounted to docker. Is used to build JCentral.')
@click.option('--replica-name', default="JCentral-dev",
              help='Searches for the container with the name.')
@click.option('--jar', default="../alien.jar", required=True,
              help='The path to jar files. Is used to build JCentral')
@click.option('--image', default=DEFAULT_DOCKER_IMAGE,
              help="Name of Docker image to be used for the container")
@click.option('--cleanup/--no-cleanup', default=True)
@click.option("--setup", default=".")
@click.option("--cmd", default="bash /jalien-setup/bash-setup/entrypoint.sh")
# pylint: disable=too-many-arguments
def start(volume, replica_name, jar, image, cleanup, setup, cmd):
    """Creates and runs JCentral replica inside Docker"""
    jalien_setup_repo = Path().expanduser().absolute()
    volume = Path(volume).expanduser().absolute()
    jar = Path(jar).expanduser().absolute()

    try:
        bootstrap_workspace(volume, jar, cleanup)
        jalien_container, xrootd_container = start_container(jalien_setup_repo, volume, image, replica_name, cmd)
        wait_for_service(jalien_container)
        wait_for_service(xrootd_container)
    # pylint: disable=bare-except,broad-except,invalid-name
    except Exception as e:
        logging.error("Something went wrong, unable to start the service...")
        logging.exception(e)

@jalien_docker.command()
@click.option('--volume', default="/tmp/jalien-replica", required=True,
              help='The path mounted to docker. Is used to build JCentral.')
@click.option('--replica-name', default="JCentral-dev",
              help='Searches for the container with the name.')
@click.option('--jar', default="../alien.jar", required=True,
              help='The path to jar files. Is used to build JCentral')
@click.option('--image', default=DEFAULT_DOCKER_IMAGE,
              help="Name of Docker image to be used for the container")
@click.option('--cleanup/--no-cleanup', default=True)
# pylint: disable=too-many-arguments
def shell(volume, replica_name, jar, image, cleanup):
    """
    Start container and open the shell without running setup.
    """
    volume = Path(volume).expanduser().absolute()
    jar = Path(jar).expanduser().absolute()

    try:
        bootstrap_workspace(volume, jar, cleanup)
        start_container(volume, image, replica_name, "/bin/bash")
        print(f"Now run: docker attach {replica_name}")
    # pylint: disable=bare-except
    except:
        logging.error("Something went wrong, unable to start container")

@jalien_docker.command()
@click.option('--replica-name',
              default="JCentral-dev", help='Searches for the container with the name.',
              show_default="Uses JCentral-dev")
def stop(replica_name):
    """ Stops JCentral replica container """
    client = docker.from_env()
    try:
        jalien_containers_list = client.containers.list(filters={'name':replica_name})
        jalien_containers_list[0].stop()
        jalien_containers_list[1].stop()
        call("docker network rm localhost", shell=True)
    except IndexError:
        logging.warning("Something went wrong." \
                        "Please check if container %s is running", replica_name)

if __name__ == '__main__':
    jalien_docker()
