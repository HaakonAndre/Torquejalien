### Quick start for xrootd container:

#### Prerequisites:
The jalien-replica.py script must be run successfully (with JCentral-replica running in the background) before manually starting the xrootd container via the below mentioned commands.

First make sure to be in the xrootd directory of the repository
- Run `docker build -t <image-name> .`
- Run `docker run -p 1094:1094 -v <path>/<to>/<shared volume>/<with jcentral replica>:/jalien-dev -it <image-name> /bin/bash`.

Note currently this uses default directory `/tmp` and storage is not persistent.

To run without usage of envelope verification change:
`CMD xrootd -c /etc/xrootd/xrootd-standalone.cfg` to `CMD xrootd` in `Dockerfile` before building image.

#### Test commands:
With alien.py setup (via sourcing env_setup.sh from your shared volume with JCentral-replica) run the following:

```
[root@51aaba2b3155 /]# alien.py cp <file name> alien://
jobID: 1/1 >>> Start
jobID: 1/1 >>> ERRNO/CODE/XRDSTAT 0/0/0 >>> STATUS OK >>> SPEED 8.17 KiB/s MESSAGE: [SUCCESS] 
```
File can also be seen via the interative shell:

```
[root@51aaba2b3155 /]# alien.py
Welcome to the ALICE GRID
support mail: adrian.sevcenco@cern.ch

AliEn[jalien]:/localhost/localdomain/user/j/jalien/ >ls
env_setup.sh
```