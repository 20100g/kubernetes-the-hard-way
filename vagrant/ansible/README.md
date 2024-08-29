# Setup Ansible in a Virtual Env
cd ~
python3 -m venv ansible_venv
cd -
source ~/ansible_venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install ansible

ansible-galaxy install -r requirements.yml

cat <<EOF > ~/.ansible.cfg 
[defaults]
host_key_checking = False
EOF