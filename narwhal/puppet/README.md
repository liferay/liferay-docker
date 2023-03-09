# Usage

## apply changes on a node
### TL;DR

```bash
# on local computer
apt install git-lfs
git clone ssh://github.com/liferay/liferay-docker.git
# make changes in narwhal/puppet/
# if there is a binary file added, it should be marked with the LFS attribute
git lfs track <relative file path from the git root directory>
git add . && git commit && git push

# deploy changes with r10k to the puppet server
/root/r10k-run.sh

# deploy changes to the node (as root):
puppet agent -t
```

### New node
```bash
# clean up previous certificate on the puppet server
clean <node's FQDN>

# on the node
wget https://apt.puppetlabs.com/puppet7-release-jammy.deb
dpkg -i puppet7-release-jammy.deb
apt update
apt install puppet-agent
/opt/puppetlabs/bin/puppet agent -t --server <puppet server FQDN>

# on the puppet server sign the CSR
puppetserver ca sign --all

# on the node apply changes
/opt/puppetlabs/bin/puppet agent -t --server <puppet server FQDN>
```
## Rules
### Linter
* Follow the puppet styleguide, except:
  * 140chars-check
  * documentation-check
  * variable_is_lowercase-check

Checking with linter:
```bash
apt install puppet-lint
puppet-lint --no-140chars-check --no-documentation-check --no-variable_is_lowercase-check
```

### Best practice:
* `case` statements should default to `fail` in order to avoid accidents
* Test branches should be prefixed with `p_<username>_` (eg. `tompos_whatever`) in order to ease the deployment and identification

## Secrets
Secrets must not be added to the repository.

## Agent management on nodes

### Regular updates
Agent defined as a cron job in `/etc/cron.d/puppet-agent` It can be disabled by commenting out the job.

### Aliases
* pat: puppet agent -t
* patn: puppet agent -t --noop
* pate: puppet agent -t --environment
* patne: puppet agent -t --noop --environment

Test environments can be defined via `p_<branch>` (eg. `p_tompos_whatever`).

