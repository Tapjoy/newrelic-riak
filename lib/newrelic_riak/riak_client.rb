require 'new_relic/agent/method_tracer'


DependencyDetection.defer do
  @name = :riak_client

  depends_on do
    defined?(::Riak) and not NewRelic::Control.instance['disable_riak_client']
  end

  executes do
    NewRelic::Agent.logger.debug 'Installing Riak client instrumentation'
  end

  executes do

    # Make this bad boy re-usable
    backend_tracers = Proc.new do |klass|
      NewRelic::Agent::Datastores.trace klass, :ping

      NewRelic::Agent::Datastores.trace klass, :list_buckets
      NewRelic::Agent::Datastores.trace klass, :get_bucket_props
      NewRelic::Agent::Datastores.trace klass, :set_bucket_props

      NewRelic::Agent::Datastores.trace klass, :mapred

      NewRelic::Agent::Datastores.trace klass, :list_keys
      NewRelic::Agent::Datastores.trace klass, :reload_object
      NewRelic::Agent::Datastores.trace klass, :delete_object
    end

    get_set_callback = Proc.new do |result, scoped_metric, elapsed|
      NewRelic::Agent::Datastores.notice_statement(query, scoped_metric, elapsed)
    end

    # Instrument measuring the store_object Callbacks

    # Instrument the ProtobuffsBackend
    backend_tracers ::Riak::Client::BeefcakeProtobuffsBackend
    NewRelic::Agent::Datastores.trace ::Riak::Client::BeefcakeProtobuffsBackend, :server_info
    NewRelic::Agent::Datastores.trace ::Riak::Client::BeefcakeProtobuffsBackend, :get_client_id
    NewRelic::Agent::Datastores.trace ::Riak::Client::BeefcakeProtobuffsBackend, :set_client_id
    NewRelic::Agent::Datastores.trace ::Riak::Client::BeefcakeProtobuffsBackend, :get_index

    # Instrument the HTTPBackend
    backend_tracers ::Riak::Client::HTTPBackend
    NewRelic::Agent::Datastores.trace ::Riak::Client::HTTPBackend, :stats
    NewRelic::Agent::Datastores.trace ::Riak::Client::HTTPBackend, :link_walk
    NewRelic::Agent::Datastores.trace ::Riak::Client::HTTPBackend, :get_index
    NewRelic::Agent::Datastores.trace ::Riak::Client::HTTPBackend, :search
    NewRelic::Agent::Datastores.trace ::Riak::Client::HTTPBackend, :update_search_index

    # Instrument RObject
    NewRelic::Agent::Datastores.trace ::Riak::RObject, :serialize

    ::Riak::Client.class_eval do

      def store_object_with_newrelic_trace(*args, &blk)
        total_metric = 'ActiveRecord/allOther'
        if NewRelic::Agent::Instrumentation::MetricFrame.recording_web_transaction?
          total_metric = 'ActiveRecord/allWeb'
        end

        robject = args[0].is_a?(Array) ? args[0][0] : args[0]
        bucket = robject.respond_to?(:bucket) && robject.bucket ? robject.bucket.name : ''
        bucket = self.newrelic_riak_camelize(bucket)

        NewRelic::Agent::Datastores.wrap("Riak", "save", bucket, get_set_callback) do
          begin
            store_object_without_newrelic_trace(*args, &blk)
          rescue => e
            # NOOP apparently?
          end
        end
      end

      def get_object_with_newrelic_trace(*args, &blk)
        total_metric = 'ActiveRecord/allOther'
        if NewRelic::Agent::Instrumentation::MetricFrame.recording_web_transaction?
          total_metric = 'ActiveRecord/allWeb'
        end

        bucket = args[0].is_a?(Array) ? args[0][0] : args[0]
        bucket = bucket && bucket.respond_to?(:name) ? bucket.name : bucket.to_s
        bucket = self.newrelic_riak_camelize(bucket)

        NewRelic::Agent::Datastores.wrap("Riak", "find", bucket, get_set_callback) do
          begin
            get_object_without_newrelic_trace(*args, &blk)
          rescue => e
            # NOOP apparently?
          end
        end
      end

      alias_method :store_object_without_newrelic_trace, :store_object
      alias_method :store_object, :store_object_with_newrelic_trace
      alias_method :get_object_without_newrelic_trace, :get_object
      alias_method :get_object, :get_object_with_newrelic_trace

      # turn bucket-name-for-things_that_ar-ok into BucketNameForThingsThatArOk
      def newrelic_riak_camelize(term)
        string = term.to_s.capitalize
        string.gsub(/[_-]([a-z]*)/) { "#{$1.capitalize}" }
      end
    end

  end
end
