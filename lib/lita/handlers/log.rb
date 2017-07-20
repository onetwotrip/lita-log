module Lita
  module Handlers
    class Log < Handler
      config :data_dir, default: '/opt/lita/data'
      config :channel, default: nil
      config :env_list, default: ['production']

      attr_accessor :data
      attr_accessor :ops_log

      http.get '/:env/current', :env_current
      http.get '/', :all_current

      route(
        /Finished deploying/,
        :add_log,
        command: false,
        help: {
          'Finished deploying something to env' => 'Lita add it to log'
        }
      )

      route(
        %r{^log\s.*$}i,
        :add_ops_log,
        command: true,
        help: {
          'log' => 'Add message to lita'
        }
      )

      def initialize(robot)
        super
        self.data = {}
        check_dir
        load_data
        load_ops_log
      end

      def check_dir
        Dir.mkdir(config.data_dir) unless Dir.exist?(config.data_dir)
      end

      def load_data
        Dir.foreach(config.data_dir) do |file|
          next unless file =~ /.json/
          next if file =~ /ops_log/
          env = file.chomp('.json')
          self.data[env] = JSON.parse(IO.read("#{config.data_dir}/#{file}", encoding: 'utf-8')) if File.exist?("#{config.data_dir}/#{file}")
        end
      end

      def load_ops_log
        return unless File.exist?("#{config.data_dir}/ops_log.json")
        self.ops_log = JSON.parse(IO.read("#{config.data_dir}/ops_log.json", encoding: 'utf-8'))
      end

      def save_data
        self.data.each do |env, _|
          filename = "#{config.data_dir}/#{env}.json"
          File.write(filename, self.data[env].to_json)
        end
      end

      def save_ops_log(hash)
        self.ops_log ||= []
        self.ops_log << hash
        filename = "#{config.data_dir}/ops_log.json"
        File.write(filename, self.ops_log.to_json)
        ES.put(hash, 'ops_log')
      end

      def save_env(env, hash)
        self.data[env] ||= []
        self.data[env] << hash
        save_data
        ES.put(hash, 'deploy')
      end

      def add_ops_log(response)
        cut = response.message.body.size - 4
        msg = response.message.body[-cut..-1]
        response.reply("#{response.user.name}, ok saved to log.")
        save_ops_log(timestamp: Time.now.to_i, user: response.user.name, msg: msg)
      end

      def add_log(response)

        full_msg = response.message.body
        user     = ''
        commit   = ''
        env      = ''
        proj     = ''

        if /by\s+(?<user>\S+)\s+Stage:\s+(?<env>\S+)\s+Projects:\s+(?<proj>\S+)\s+Branch:\s+(?<commit>\S+)/ =~ full_msg

          user.delete!('*')
          commit.delete!('*').delete!('[').delete!(']')
          env.delete!('*')
          proj.delete!('*').delete!('[').delete!(']').downcase
          msg = "#{user}, #{proj} (#{commit}) to #{env}"

          save_env(env, msg: msg,
                   environment: env, timestamp: Time.now.to_i,
                   user: user, project: proj, commit: commit)
        else
          save_env(env, msg: full_msg,
                   environment: 'null', timestamp: Time.now.to_i,
                   user: 'null', project: 'null', commit: 'null')
        end
      end

      def env_claimer(env)
        Claim.read(env)
      end

      def env_latest(env)
        last_env = self.data[env].last
        last_env['claimer'] = env_claimer(env)
        last_env
      end

      def all_current(request, response)
        all = {}
        self.data.each_key do |env|
          all[env] = env_latest(env)
        end
        html = render_template('index', variables: { envs: all, ops_log: self.ops_log })
        response.body << html
      end

      def env_current(request, response)
        env = request.env['router.params'][:env]
        html = render_template('env', variables: { env => self.data[env] })
        response.body << html
      end
    end
    Lita.register_handler(Log)
  end
end
