module Lita
  module Handlers
    class Log < Handler
      route(/Finished deploying/, :log_deploy, command: false, help: {
        'Finished deploying something to env' => 'Lita add it to log'
      })

      route(/^log(\s+(\S+))?\s+(.*)$/i, :log_message, command: true, help: {
        'log some text'            => 'Save "some text" to index lita with tag shared',
        'log _<project> some text' => 'Save "some text" to index lita with tag <project>',
      })

      def log_message(response)
        message = response.matches.first.compact
        user    = response.user.name

        if message.size == 1
          ES.put({ user: user, message: message.last, tags: [user, 'shared']})

          response.reply("#{user}, ok saved to shared log")
        elsif message.size == 3
          message = message[1..-1]

          if message.first.start_with?('_')
            ES.put({ user: user, message: message.last, tags: [user, message.first.delete('_')]})

            response.reply("#{user}, ok saved to #{message.first} log")
          else
            ES.put({ user: user, message: message.join(' '), tags: [user, 'shared']})

            response.reply("#{user}, ok saved to shared log")
          end
        else
          response.reply("#{user}, sorry, something went wrong")
        end
      end

      def log_deploy(response)
        full_msg                = response.message.body
        user, commit, env, proj = 'null', 'null', 'null', 'null'

        if /by\s+(?<user>\S+)\s+Stage:\s+(?<env>\S+)\s+Projects:\s+(?<proj>.*)\s+Branch:\s+(?<commit>.*)/ =~ full_msg
          user   = user.delete('*')
          commit = commit.delete('*').delete('[').delete(']')
          env    = env.delete('*')
          proj   = proj.strip.delete('*').delete('[').delete(']').downcase

          msg = "#{user}, #{proj} (#{commit}) to #{env}"
        else
          msg = full_msg
        end

        ES.put({
          message:     msg,
          environment: env,
          user:        user,
          project:     proj,
          commit:      commit,
          tags:        [user, 'deploy']
        })
      end
    end

    Lita.register_handler(Log)
  end
end
