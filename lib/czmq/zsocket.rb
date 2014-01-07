require 'czmq-ffi'


module CZMQ
  class ZSocket

    def initialize(zctx, type, opts = {})
      @zctx = zctx
      @zsocket = LibCZMQ.zsocket_new(zctx, type)
      # TODO: Maybe check that zsocket is not null?

      setup_finalizer
    end

    def close
      if @zsocket
        # Since we explicitly close the zsocket, we have to remove the finalizer.
        remove_finalizer
        LibCZMQ.zsocket_destroy(@zctx, @zsocket)
        @zsocket = nil
      end
    end

    def bind(address, opts={})
      raise "Can't bind a closed ZSocket!" unless @zsocket
      # TODO: pass opts to zsocket_bind using varargs
      LibCZMQ.zsocket_bind(@zsocket, address)
    end

    def unbind(address, opts={})
      raise "Can't unbind a closed ZSocket!" unless @zsocket
      # TODO: pass opts to zsocket_unbind using varargs
      LibCZMQ.zsocket_unbind(@zsocket, address)
    end

    def connect(address, opts={})
      raise "Can't connect a closed ZSocket!" unless @zsocket
      # TODO: pass opts to zsocket_connect using varargs
      LibCZMQ.zsocket_connect(@zsocket, address)
    end

    def disconnect(address, opts={})
      raise "Can't disconnect a closed ZSocket!" unless @zsocket
      # TODO: pass opts to zsocket_disconnect using varargs
      LibCZMQ.zsocket_disconnect(@zsocket, address)
    end

    def poll(msecs)
      raise "Can't poll a closed ZSocket!" unless @zsocket
      LibCZMQ.zsocket_poll(@zsocket, msecs)
    end

    def type
      raise "Can't read type of a closed ZSocket!" unless @zsocket
      LibCZMQ.zsocket_type_str(@zsocket)
    end

    def receive_string(*opts)
      if opts.include? :no_wait
        # NOTE: There is no need to raise exception if zstr_recv_nowait returns
        # NULL. That's a perfectly fine result, meaning that we don't have any
        # strings in the CZMQ RX buffers.
        LibCZMQ.zstr_recv_nowait(@zsocket)
      elsif opts.include? :multipart
        # TODO: Call zstr_recvx
      else
        str = LibCZMQ.zstr_recv(@zsocket)
        # TODO: Do we really need to raise an exception if the string is nil?
        raise "Can't read string from ZSocket" if str.nil?
        str
      end
    end

    def send_string(str, *opts)
      if opts.include? :more
        LibCZMQ.zstr_sendm(@zsocket, str)
        # TODO: check the code returned by zstr_sendm?
      elsif opts.include? :multipart
        # TODO: call zstr_sendx
      else
        LibCZMQ.zstr_send(@zsocket, str)
        # TODO: check the code returned by zstr_send?
      end
    end

    # TODO: implement this
    # def sendmem
    #   raise "Can't sendmem to a closed ZSocket!" unless @zsocket
    # end

    private

      # After object destruction, make sure that the corresponding zsocket is
      # destroyed as well.
      #
      # NOTE: We don't care about ensuring, as ffi-rmzq does, that the resource
      # deallocation request comes from the process that allocated it in the first place.
      # In fact, the CZMQ documentation at http://zeromq.org/area:faq explicitly states
      # "It is not safe to share a context or sockets between a parent and its child."
      def setup_finalizer
        ObjectSpace.define_finalizer(self, self.class.close_zsocket(@zctx, @zsocket))
      end

      def remove_finalizer
        ObjectSpace.undefine_finalizer self
      end

      # Need to make this a class method, or the deallocation won't take place. See:
      # http://www.mikeperham.com/2010/02/24/the-trouble-with-ruby-finalizers/
      def self.close_zsocket(zctx, zsocket)
        Proc.new do
          LibCZMQ.zsocket_destroy(zctx, zsocket)
        end
      end
  end
end
