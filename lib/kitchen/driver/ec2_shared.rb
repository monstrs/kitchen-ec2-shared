#
# Author:: Andrey Linko (<AndreyLinko@gmail.com>)
#
# Copyright (C) 2015, Andrey Linko
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'benchmark'
require 'json'
require 'fog'
require 'net/ssh'
require 'net/scp'
require 'kitchen/driver/ec2'

module Kitchen
  module Driver
    class Ec2Shared < Kitchen::Driver::Ec2
      # (see Base#converge)
      def converge(state) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        provisioner = instance.provisioner
        provisioner.create_sandbox
        sandbox_dirs = Dir.glob("#{provisioner.sandbox_path}/*")

        Kitchen::SSH.new(*build_ssh_args(state)) do |conn|
          run_remote(provisioner.install_command, conn)
          run_remote(provisioner.init_command, conn)
          transfer_path(sandbox_dirs, provisioner[:root_path], conn)
          upload_nodes(state)
          run_remote(provisioner.prepare_command, conn)
          run_remote(provisioner.run_command, conn)
        end

        download_node(state)
      ensure
        provisioner && provisioner.cleanup_sandbox
      end

      def destroy(state)
        super
        FileUtils.rm_f("#{nodes_dir}/#{instance.name}.json")
      end

      def upload_nodes(state)
        session = establish_connection(*build_ssh_args(state))
        session.exec!("mkdir -p #{remote_nodes_dir}")

        nodes.each do |node|
          session.scp.upload!(node, "#{remote_nodes_dir}/#{File.basename(node)}")
        end

        session.close
      end

      def download_node(state)
        session = establish_connection(*build_ssh_args(state))
        session.scp.download!("#{remote_nodes_dir}/#{instance.name}.json", nodes_dir)
        session.close
      end

      def nodes
        Dir.glob("#{nodes_dir}/**").reject do |node|
          /#{instance.name}\.json$/.match(node)
        end
      end

      def nodes_dir
        path = File.expand_path(File.join('.kitchen', 'nodes'))
        FileUtils.mkdir_p(path)
        path
      end

      def remote_nodes_dir
        "#{instance.provisioner[:root_path]}/nodes"
      end

      def establish_connection(hostname, username, options) # rubocop:disable Metrics/MethodLength
        rescue_exceptions = [
          Errno::EACCES, Errno::EADDRINUSE, Errno::ECONNREFUSED,
          Errno::ECONNRESET, Errno::ENETUNREACH, Errno::EHOSTUNREACH,
          Net::SSH::Disconnect, Net::SSH::AuthenticationFailed
        ]
        retries = config[:ssh_retries] || 3

        begin
          debug("[SSH] opening connection to #{self}")
          Net::SSH.start(hostname, username, options)
        rescue *rescue_exceptions => e
          retries -= 1
          if retries > 0
            info("[SSH] connection failed, retrying (#{e.inspect})")
            sleep config[:ssh_timeout] || 1
            retry
          else
            warn("[SSH] connection failed, terminating (#{e.inspect})")
            raise
          end
        end
      end
    end
  end
end
