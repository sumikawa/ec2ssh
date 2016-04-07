# ec2ssh

## How to install

- install percol, inifile and AWS SDK for Ruby v2

```
pip install percol
gem install inifile aws-sdk
```

- copy files to somewhere in exec path
 
```
git clone git@github.com:sumikawa/ec2ssh.git
cd ec2ssh
cp ec2ssh get_instances.rb /usr/local/bin/
```

## Usage

- add your private key file to ssh-agent

```
ssh-add ~/.ssh/<YOUR_PRIVATE_KEY>.pem
```

- run ec2ssh and select an instance you want to log in to

```
ec2ssh
```