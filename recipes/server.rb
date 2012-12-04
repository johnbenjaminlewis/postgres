# Install PG server from sources
# Creates user if necessary
# Initializes data directory if not found

# Used to determine what IP addresses to bind
def listen_addr_for interface
  interface_node = node['network']['interfaces'][interface]['addresses']
  interface_node.select { |address, data| data['family'] == 'inet' }[0][0]
end

include_recipe "postgres::build"

case node['platform']
  when "smartos"
    available_ram = `prtconf -m`.chomp.to_i
end

node.default['postgres']['config']['shared_buffers_mb'] = (available_ram * 0.25).to_i
node.default['postgres']['config']['effective_cache_size_mb'] = (available_ram * 0.7).to_i

config        = node['postgres']['config']
os_user       = node['postgres']['user']
os_group      = node['postgres']['group']
service_name  = node['postgres']['service']
data_dir      = node['postgres']['data_dir']
bin_dir       = node['postgres']['prefix_dir'].gsub(/%VERSION%/, node['postgres']['version']) + "/bin"
shell_script  = "/opt/local/share/smf/method/postgres-#{node['postgres']['version']}.sh"

# create postgres user if not already there
user os_user do
  comment "PostgreSQL User"
  action :create
end

group os_group do
  action :create
end

directory config["stats_temp_directory"] do
  owner os_user
  group os_group
end

directory "/opt/local/share/smf/method" do
  recursive true
  action :create
end

directory File.dirname(data_dir) do
  recursive true
  owner os_user
end

directory File.dirname(node['postgres']['log_file']) do
  recursive true
  owner os_user
  group os_group
end

execute "running initdb for data dir #{data_dir}" do
  command "#{bin_dir}/initdb -D #{data_dir} -E 'UTF8'"
  user os_user
  not_if { File.exists?(data_dir)}
end

template shell_script do
  source "postgres-service.sh.erb"
  mode "0700"
  owner os_user
  group os_group
  notifies :reload, "service[#{service_name}]"
  variables(
      "bin_dir"  => bin_dir,
      "data_dir" => node['postgres']['data_dir'],
      "log_file" => node['postgres']['log_file']
  )
end

template "#{data_dir}/pg_hba.conf" do
  source "pg_hba.conf.erb"
  owner os_user
  group os_group
  mode "0600"
  notifies :reload, "service[#{service_name}]"
  variables('replica' => false, 'connections' => node['postgres']['connections'] )
end

if node['postgres']['listen_addresses'].empty?
  node['postgres']['listen_interfaces'].each do |interface|
    node.default['postgres']['listen_addresses'] << listen_addr_for(interface)
  end
end

if node['postgres']['listen_addresses'].empty?
  raise "Can't find any listen_addresses to bind to"
end

template "#{data_dir}/postgresql.conf" do
  source "postgresql.conf.erb"
  owner os_user
  group os_group
  mode "0600"
  notifies :reload, "service[#{service_name}]"
  variables config.to_hash.merge('listen_addresses' => node['postgres']['listen_addresses'])
end


#if config['replica']
#  template "#{data_dir}/recovery.conf" do
#    source "#{os}.recovery.conf.erb"
#    owner os_user
#    group os_group
#    mode "0600"
#    notifies :reload, "service[#{service_name}]"
#    variables params
#  end
#end

smf service_name do
  user os_user
  group os_group
  start_command "#{shell_script} start"
  stop_command "#{shell_script} stop"
  refresh_command "#{shell_script} refresh"
  start_timeout 60
  stop_timeout 60
  refresh_timeout 60

  environment(
      "LD_PRELOAD_32" => "/usr/lib/extendedFILE.so.1"
  )
end

service service_name do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end
