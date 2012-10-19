require 'guard'
require 'guard/guard'
require 'json'

module Guard
  class Tork < Guard

    # Initialize a Guard.
    # @param [Array<Guard::Watcher>] watchers the Guard file watchers
    # @param [Hash] options the custom Guard options
    def initialize(watchers = [], options = {})
      super
      @handler = options[:event_handler]
    end

    # Call once when Guard starts. Please override initialize method to init stuff.
    # @raise [:task_has_failed] when start has failed
    def start
      @engine = IO.popen('tork-engine', 'r+')
      @reader = Thread.new do
        # we must always read and decode messages from the engine, even if
        # there is no event handler specified, because it may send us error
        # messages in response to requests we dispatch from within this guard
        while message = @engine.gets
          begin
            decoded = JSON.load(message)
            @handler.call decoded if @handler
          rescue JSON::ParserError
            UI.error message
          end
        end
      end
    end

    # Called when `stop|quit|exit|s|q|e + enter` is pressed (when Guard quits).
    # @raise [:task_has_failed] when stop has failed
    def stop
      @reader.exit
      @engine.close_write # tork-engine(1) exits when its STDN is closed
      @engine.close       # wait for process to exit and reap its zombie
    end

    # Called when `reload|r|z + enter` is pressed.
    # This method should be mainly used for "reload" (really!) actions like reloading passenger/spork/bundler/...
    # @raise [:task_has_failed] when reload has failed
    def reload
      @engine.puts JSON.dump([:reabsorb_overhead])
    end

    # Called when just `enter` is pressed
    # This method should be principally used for long action like running all specs/tests/...
    # @raise [:task_has_failed] when run_all has failed
    def run_all
      @engine.puts JSON.dump([:rerun_failed_test_files])
    end

    # Called on file(s) modifications that the Guard watches.
    # @param [Array<String>] paths the changes files or paths
    # @raise [:task_has_failed] when run_on_change has failed
    def run_on_changes(paths)
      @engine.puts JSON.dump([:run_test_files, paths])
    end

    ## Called on file(s) deletions that the Guard watches.
    ## @param [Array<String>] paths the deleted files or paths
    ## @raise [:task_has_failed] when run_on_change has failed
    #def run_on_removals(paths)
    #end

  end
end
