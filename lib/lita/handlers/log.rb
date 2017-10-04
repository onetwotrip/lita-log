module Lita
  module Handlers
    class Log < Handler
      config :data_dir, default: '/opt/lita/data'
      config :channel, default: nil
      config :env_list, default: ['production']

      attr_accessor :data
      attr_accessor :ops_log

      http.get '/:env/current', :env_current

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
        check_dir
      end

      def check_dir
        Dir.mkdir(config.data_dir) unless Dir.exist?(config.data_dir)
      end

      def read_data(env)
        filename = "#{config.data_dir}/#{env}.json"

        if File.exist?(filename)
          IO.read(filename, encoding: 'utf-8').split("\n")
        else
          return "Can't find file #{filename}"
        end
      end

      def save_data(env, hash)
        filename = "#{config.data_dir}/#{env}.json"
        File.open(filename, "a+") { |f| f << "#{hash.to_json}\n" }
      end

      def save_ops_log(hash)
        save_data('ops_log', hash)
        ES.put(hash, 'ops_log')
      end

      def save_env(env, hash)
        save_data(env, hash)
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
        user     = 'null'
        commit   = 'null'
        env      = 'null'
        proj     = 'null'

        if /by\s+(?<user>\S+)\s+Stage:\s+(?<env>\S+)\s+Projects:\s+(?<proj>.*)\s+Branch:\s+(?<commit>.*)/ =~ full_msg

          user.delete!('*')
          commit.delete!('*').delete!('[').delete!(']')
          env.delete!('*')
          proj.strip!.delete!('*').delete!('[').delete!(']').downcase

          msg = "#{user}, #{proj} (#{commit}) to #{env}"
        else
          msg = full_msg
        end

        save_env(
          env,
          msg: msg,
          environment: env,
          timestamp: Time.now.to_i,
          user: user,
          project: proj,
          commit: commit
        )
      end

      def env_current(request, response)
        env  = request.env['router.params'][:env]
        html = render_template('env', variables: { env => read_data(env) })
        response.body << html
      end
    end
    Lita.register_handler(Log)
  end
end
