#!/bin/bash

sudo gcimagebundle -d /dev/sda -r / -o /tmp --loglevel=DEBUG --log_file=/tmp/image_bundle.log
