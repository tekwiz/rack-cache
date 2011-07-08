require 'rack/cache/observer'

module Rack::Cache
  # Observable is included into Rack::Cache::Context.
  module Observable
    CALLBACKS = [:on_request, :before_forward]
    RESPONSE_CALLBACKS = [:after_forward, :on_hit]

    # Thrown in the event an invalid callback is run.
    class InvalidCallback < Exception
    end

    # Evaluates the validity of a callback call
    def self.valid_callback?(name, arity)
      case arity
      when 0: CALLBACKS.include?(name.to_sym)
      when 1: RESPONSE_CALLBACKS.include?(name.to_sym)
      else false
      end
    end

    def self.included(base)
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

    module ClassMethods
      # The array of Observers
      def observers
        @observers ||= []
      end

      # Adds an observer
      def add_observer(observer)
        unless observer.ancestors.include?(Rack::Cache::Observer)
          raise TypeError, "#{observer.inspect} expected to be kind_of Rack::Cache::Observer"
        end
        self.observers << observer unless self.observers.include?(observer)
      end
    end

    module InstanceMethods
      # Runs the given callback for all the observers
      #
      # Examples:
      #   
      #   run_observers(:on_request)
      #   run_observers(:on_hit, response)
      #   run_observers(:before_forward, an_object) => raises InvalidCallback
      def run_observers(sym, *args)
        unless Rack::Cache::Observable.valid_callback?(sym.to_sym, args.length)
          raise InvalidCallback, "Invalid observer callback: #{sym}(#{args.collect(&:inspect).join(", ")})"
        end

        self.class.observers.each do |observer|
          observer.new(@env, @request).send(sym.to_sym, *args)
        end
      end
    end
  end
end
