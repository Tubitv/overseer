# Bootloader & packing scripts

This folder contains the initial bootloader code that will be put into a prebuild AMI. Once this AMI is bring life, the bootloader service will run and it will setup node name and cookie, then connect to overseer node.

## Usage

First of all, please make sure you have [packer](https://www.packer.io/) and [ansible](https://www.ansible.com/) installed. Packer is for building the AMI and ansible is for privisioning the server so that it has the basic functionality.

You also need to properly setup AWS environment for your local machine. You may start with: [aws configure](https://docs.aws.amazon.com/cli/latest/reference/configure/).

Then you can run `make`.

## Customizing the bootloader

If you're not satisfied the default bootloader, you can build your own - just modify the code under "bootloader" and the code under "ansible".
