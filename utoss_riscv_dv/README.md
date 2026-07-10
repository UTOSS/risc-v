To install riscv-dv:

```
sudo apt update
sudo apt install -y git python3 python3-pip make

mkdir -p ~/tools
git clone https://github.com/chipsalliance/riscv-dv.git ~/tools/riscv-dv
cd ~/tools/riscv-dv

pip3 install -r requirements.txt
pip3 install --user -e .

echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
echo 'export RISCV_DV_HOME=$HOME/tools/riscv-dv' >> ~/.bashrc
source ~/.bashrc
```

Usage:
```
make riscv_dv
```