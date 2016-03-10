class WG
  module MethodDecorator

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def configure
        yield(self)
      end

      # override this method to implement decorator
      def default_decorator(klass, method_name, options, tag, method_binding, method_args, method_block)
        method_binding.call(*method_args, &method_block)
      end

      def decorate_method(options, &block)
        @decorators << [options, block]
      end

      def decorate_application
        @decorators.each do |options, tag_block|
          decorator                   =   method( options.delete(:decorator) || :default_decorator )
          target                      =   options.delete(:target)
          klass                       =   target.constantize

          klass_methods = extract_methods_from_options(klass, options, :instance_methods, :instance_methods) -
            extract_methods_from_options(klass, options, :instance_methods, :except_instance_methods)

          klass_methods.each { |method_name|
            decorate_instance_method klass, decorator, method_name, options, tag_block
          }

          meta_klass_methods = extract_methods_from_options(klass, options, :methods, :class_methods) -
            extract_methods_from_options(klass, options, :methods, :except_class_methods)

          meta_klass_methods.each { |method_name|
            decorate_class_method klass, decorator, method_name, options, tag_block
          }
        end
      end

      def extract_methods_from_options(klass, options, type, key)
        if methods = options.delete(key)
          methods = [methods] unless methods.is_a?(Array)
          methods.map { |method|
            case method
            when true
              # .methods & .instance_methods return public & protected only
              lookup_methods(klass, type) + lookup_methods(klass, "private_#{type}".to_sym)
            when :private
              lookup_methods(klass, "private_#{type}".to_sym)
            when :public
              lookup_methods(klass, "public_#{type}".to_sym)
            when :protected
              lookup_methods(klass, "protected_#{type}".to_sym)
            else
              method
            end
          }.flatten.uniq
        else
          []
        end
      end

      def lookup_methods(klass, op)
        klass.send(op) - Object.send(op)
      end

      def decorate_instance_method(klass, decorator, method_name, options, tag_block)
        tag = options[:tag] || "#{klass.name}.#{method_name}"
        #ap "decorating #{tag}"

        klass.instance_eval do
          method_binding = instance_method(method_name)
          define_method(method_name) do |*method_args, &method_block|
            tag = tag_block.call(self, tag) if tag_block.present?
            decorator.call(klass, method_name, options, tag, method_binding.bind(self), method_args, method_block)
          end
        end
      end

      def decorate_class_method(klass, decorator, method_name, options, tag_block)
        tag = options[:tag] || "#{klass.name}##{method_name}"
        #ap "decorating #{tag}"
        meta_klass = class << klass; self; end

        meta_klass.instance_eval do
          method_binding = instance_method(method_name)
          define_method(method_name) do |*method_args, &method_block|
            tag = tag_block.call(self, tag) if tag_block.present?
            decorator.call(meta_klass, method_name, options, tag, method_binding.bind(self), method_args, method_block)
          end
        end
      end

      # def metaclass(klass)
      #   class << klass; self; end
      # end
    end
  end
end
