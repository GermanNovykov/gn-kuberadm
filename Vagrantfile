require "yaml" # import yaml
settings = YAML.load_file "settings.yaml" # load file with cluster configuration AND vm settings

IP_SECTIONS = settings["network"]["control_ip"].match(/^([0-9.]+\.)([^.]+)$/) # get ip 10.0.0.10 and turn into match object
# First 3 octets including the trailing dot:
IP_NW = IP_SECTIONS.captures[0] # get ip 10.0.0.
# Last octet excluding all dots:
IP_START = Integer(IP_SECTIONS.captures[1]) # get last bit of ip, this case 10
NUM_WORKER_NODES = settings["nodes"]["workers"]["count"] # get number of workers

Vagrant.configure("2") do |config|
  config.vm.provision "shell", env: { "IP_NW" => IP_NW, "IP_START" => IP_START, "NUM_WORKER_NODES" => NUM_WORKER_NODES }, inline: <<-SHELL # set the env variables for shell
      apt-get update -y
      echo "$IP_NW$((IP_START)) master-node" >> /etc/hosts # add ip's to the /etc/hosts file, this line goes like this: $IP_NW = 10.0.0. plus IP_START = 10; entry in /etc/hosts: 10.0.0.10 master-node
      for i in `seq 1 ${NUM_WORKER_NODES}`; do # loop through 1 to number of workers, let's say 3 for example
        echo "$IP_NW$((IP_START+i)) worker-node0${i}" >> /etc/hosts # $IP_NW = 10.0.0. plus IP_START = 10 + i; for first one it would be "10.0.0.11 worker-node01", second "10.0.0.12 worker-node02"
      done
  SHELL

  if `uname -m`.strip == "aarch64" # conf if arm 64
    config.vm.box = settings["software"]["box"] + "-arm64" # get "box: bento/ubuntu-22.04" box image from "software" part of our .yaml file
  else
    config.vm.box = settings["software"]["box"] # get "box: bento/ubuntu-22.04" box image from "software" part of our .yaml file
  end
  config.vm.box_check_update = true

  config.vm.define "master" do |master| # first vagrant vm - master, who is going to have kube API control plane
    master.vm.hostname = "master-node" # change hostname
    master.vm.network "private_network", ip: settings["network"]["control_ip"] # make a private network 10.0.0.10. Similar to how we done with IP 192.168.56.5 in the course
    if settings["shared_folders"] # if there is additional shared folders. we have /vagrant mounted by default though
      settings["shared_folders"].each do |shared_folder|
        master.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
      end
    end
    master.vm.provider "virtualbox" do |vb| # now we get system specifications from settings.yaml file
        vb.cpus = settings["nodes"]["control"]["cpu"] # num of cpus
        vb.memory = settings["nodes"]["control"]["memory"] # num ram
        if settings["cluster_name"] and settings["cluster_name"] != "" # if there is cluster name and it is not empty
          vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])] # add a group by clustername
        end
    end
    master.vm.provision "shell", 
      # add env variables
      env: {
        "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
        "ENVIRONMENT" => settings["environment"],
        "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
        "OS" => settings["software"]["os"]
      },
      path: "scripts/common.sh" # upload script to the vm and execute it, the script is in our scripts folder
    master.vm.provision "shell", # this provision is unique for master
      env: {
        "CALICO_VERSION" => settings["software"]["calico"],
        "CONTROL_IP" => settings["network"]["control_ip"],
        "POD_CIDR" => settings["network"]["pod_cidr"],
        "SERVICE_CIDR" => settings["network"]["service_cidr"]
      },
      path: "scripts/master.sh" # upload script to the vm and execute it
  end

  (1..NUM_WORKER_NODES).each do |i| # 1 to number of worker nodes, each create vm

    config.vm.define "node0#{i}" do |node|
      node.vm.hostname = "worker-node0#{i}"
      node.vm.network "private_network", ip: IP_NW + "#{IP_START + i}" # 10.0.0.11 for first machine
      if settings["shared_folders"]
        settings["shared_folders"].each do |shared_folder|
          node.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
        end
      end
      node.vm.provider "virtualbox" do |vb| # add specifications of workers, this time we take "workers" 
          vb.cpus = settings["nodes"]["workers"]["cpu"]
          vb.memory = settings["nodes"]["workers"]["memory"]
          if settings["cluster_name"] and settings["cluster_name"] != ""
            vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
          end
      end
      node.vm.provision "shell", #add env variables for each node and run common script for all of the machines
        env: {
          "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
          "ENVIRONMENT" => settings["environment"],
          "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
          "OS" => settings["software"]["os"]
        },
        path: "scripts/common.sh"
      node.vm.provision "shell", path: "scripts/node.sh" # run script for worker node

      # Only install the dashboard after provisioning the last worker (and when enabled).
      if i == NUM_WORKER_NODES and settings["software"]["dashboard"] and settings["software"]["dashboard"] != ""
        node.vm.provision "shell", path: "scripts/dashboard.sh"
      end
    end
  end
end