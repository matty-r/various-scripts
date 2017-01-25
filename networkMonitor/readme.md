Install:

# cp /networkMonitor/net* /etc/systemd/system/
# systemctl enable networkMonitor.timer
# systemctl start networkMonitor.timer


Uninstall:

# systemctl stop networkMonitor.timer
# systemctl disable networkMonitor.timer
# rm /etc/systemd/system/networkMonitor.timer
# rm /etc/systemd/system/networkMonitor.service
# rm /etc/systemd/system/networkMonitor.script
# rm /etc/systemd/system/networkMonitor.var
