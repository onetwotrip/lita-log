# Singleton for accessing ElasticSearch
class ES
  class << self
    def timestamp
      Time.now.utc.getlocal.iso8601
    end

    def type_name
      'lita'
    end

    def index_name
      # to get current es index name
      'lita-' + (Time.now.strftime '%Y.%m.%d')
    end

    def put(msg, tag)
      msg[:@timestamp] = timestamp
      msg[:tag]        = tag
      msg              = {
        index: index_name,
        type: type_name,
        body: msg
      }
      es.index msg
    end

    def health
      es.cluster.health
    end

    def es_url
      if ENV['LITA_ES_HOST'] && ENV['LITA_ES_PORT']
        "#{ENV['LITA_ES_HOST']}:#{ENV['LITA_ES_PORT']}"
      elsif ENV['LITA_ES_HOST']
        return "#{ENV['LITA_ES_HOST']}:9200"
      elsif ENV['LITA_ES_PORT']
        return "127.1:#{ENV['LITA_ES_PORT']}"
      else
        '127.1:9200'
      end
    end

    def es
      @client ||= Elasticsearch::Client.new url: es_url, log: true
    end
  end
end
