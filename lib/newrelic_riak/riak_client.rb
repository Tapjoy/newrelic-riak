require 'new_relic/agent/datastores'

DependencyDetection.defer do
  @name = :riak_client

  depends_on do
    defined?(::Riak) and not NewRelic::Control.instance['disable_riak_client']
  end

  executes do
    NewRelic::Agent.logger.info 'Installing Riak client instrumentation'
  end

  executes do
    # Make this bad boy re-usable
    NewRelic::Agent.logger.info 'Riak: backend_tracers'
    backend_tracers = Proc.new do |klass, klass_methods, product = 'Riak'|
      klass.class_eval do
        klass_methods.each do |entry|
          NewRelic::Agent::Datastores.trace self, entry, product
        end
      end
    end

    # Instrument the ProtoBuffsBackend
    NewRelic::Agent.logger.info 'Riak: BeefcakeProtoBuffsBackend'
    method_list = %w(ping list_buckets get_bucket_props set_bucket_props mapred list_keys
                     reload_object delete_object server_info get_client_id set_client_id get_index)
    backend_tracers.call(::Riak::Client::BeefcakeProtobuffsBackend, method_list)
    
    # Instrument RObject
    NewRelic::Agent.logger.info 'Riak: RObject'
    backend_tracers.call(::Riak::RObject, ['serialize'])

    # Instrument Riak client get/store
    NewRelic::Agent.logger.info 'Riak: Wrap Riak::Client save/find with NR and alias them'
    ::Riak::Client.class_eval do
      include NewRelic::Agent::Instrumentation::Riak
      alias_method :store_object_without_newrelic_trace, :store_object
      alias_method :store_object, :store_object_with_newrelic_trace
      alias_method :get_object_without_newrelic_trace, :get_object
      alias_method :get_object, :get_object_with_newrelic_trace
    end
  end
end

module NewRelic
  module Agent
    module Instrumentation
      module Riak
        def get_set_callback
          Proc.new do |result, scoped_metric, elapsed|
            NewRelic::Agent::Datastores.notice_statement(statement, elapsed)
          end
        end

        # turn bucket-name-for-things_that_ar-ok into BucketNameForThingsThatArOk
        def newrelic_riak_camelize(term)
          string = term.to_s.capitalize
          string.gsub(/[_-]([a-z]*)/) { "#{$1.capitalize}" }
        end

        def store_object_with_newrelic_trace(*args, &blk)
          robject = args[0].is_a?(Array) ? args[0][0] : args[0]
          bucket = robject.respond_to?(:bucket) && robject.bucket ? robject.bucket.name : ''
          bucket = newrelic_riak_camelize(bucket)

          NewRelic::Agent::Datastores.wrap('Riak', 'save', bucket, get_set_callback) do
            begin
              store_object_without_newrelic_trace(*args, &blk)
            rescue => e
              # NOOP apparently?
              nil
            end
          end
        end

        def get_object_with_newrelic_trace(*args, &blk)
          bucket = args[0].is_a?(Array) ? args[0][0] : args[0]
          bucket = bucket && bucket.respond_to?(:name) ? bucket.name : bucket.to_s
          bucket = newrelic_riak_camelize(bucket)

          NewRelic::Agent::Datastores.wrap('Riak', 'find', bucket, get_set_callback) do
            begin
              get_object_without_newrelic_trace(*args, &blk)
            rescue => e
              # NOOP apparently?
              nil
            end
          end
        end
      end
    end
  end
end
