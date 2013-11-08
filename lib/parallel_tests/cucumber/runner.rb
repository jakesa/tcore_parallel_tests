require 'parallel_tests/test/runner'

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::Test::Runner
      def self.run_tests(test_files, process_number, options)
        ENV["AUTOTEST"] = "1" if $stdout.tty?#display color when we are in a terminal
        #TODO: Add verification that the log_files directory has been created
        failed_log = options[:rerun_formatter].nil? ? "" : "-f #{options[:rerun_formatter]} --out ./log_files/rerun#{process_number}.txt "
        runtime_logging = " --format ParallelTests::Cucumber::RuntimeLogger --out #{runtime_log}"
        File.new("./log_files/process_log_#{process_number}")
        process_logging = "-f pretty --out ./log_files/process_log_#{process_number}"

        cmd = [
            executable,
            (runtime_logging if File.directory?(File.dirname(runtime_log))),
            cucumber_opts(options[:test_options]),
            failed_log,
            process_logging,
        test_files
        ].compact.join(" ")
        execute_command(cmd, process_number, options)

      end

      def self.executable
        if ParallelTests.bundler_enabled?
          "bundle exec cucumber"
        elsif File.file?("script/cucumber")
          "script/cucumber"
        else
          "cucumber"
        end
      end

      def self.runtime_log
        'tmp/parallel_runtime_cucumber.log'
      end

      def self.test_file_name
        "feature"
      end

      def self.test_suffix
        ".feature"
      end

      def self.line_is_result?(line)
        line =~ /^\d+ (steps?|scenarios?)/
      end

      # cucumber has 2 result lines per test run, that cannot be added
      # 1 scenario (1 failed)
      # 1 step (1 failed)
      def self.summarize_results(results)
        sort_order = %w[scenario step failed undefined skipped pending passed]

        %w[scenario step].map do |group|
          group_results = results.grep /^\d+ #{group}/
          next if group_results.empty?

          sums = sum_up_results(group_results)
          sums = sums.sort_by { |word, _| sort_order.index(word) || 999 }
          sums.map! do |word, number|
            plural = "s" if word == group and number != 1
            "#{number} #{word}#{plural}"
          end
          "#{sums[0]} (#{sums[1..-1].join(", ")})"
        end.compact.join("\n")
      end

      def self.summarize_failures
        r, w = IO.pipe
        files = Dir.glob("./log_files/rerun*.txt")
        files.each do |file|
          text = IO.read("#{file}")
          text.split.each {|line| w << line; w << "\n"}
        end
        w.close
        output = r.read
        r.close
        output
      end

      def self.delete_log_files
        files = Dir.glob("./log_files/*.txt")
        files.each do |file|
          File.delete(file)
        end
      end

      def self.cucumber_opts(given)
        if given =~ /--profile/ or given =~ /(^|\s)-p /
          given
        else
          [given, profile_from_config].compact.join(" ")
        end
      end

      def self.profile_from_config
        # copied from https://github.com/cucumber/cucumber/blob/master/lib/cucumber/cli/profile_loader.rb#L85
        config = Dir.glob('{,.config/,config/}cucumber{.yml,.yaml}').first
        if config && File.read(config) =~ /^parallel:/
          "--profile parallel"
        end
      end

      # This is the method used for the preprocessing of the cucumber files to get the list of all the will actually be executed at runtime.
      def self.dry_run(cmd)
        $stdout << "Preprocessing test files"
        $stdout << "\n"
        r, w = IO.pipe
        cmd_pid = spawn(cmd, :out => w, :err=>:out)
        Process.waitpid2(cmd_pid)
        w.close
        output = r.read
        r.close
        output
      end

      def self.tests_in_groups(tests, num_groups, options={})
        if options[:group_by] == :steps
          Grouper.by_steps(find_tests(tests, options), num_groups)
        else
          #tests = find_tests(tests, options)
          #JS - This code executes the dry run that is responsible for get the list of actually executed tests.  It then parses the results by line and then into groups
          tests = dry_run(["cucumber",options[:files] , '--dry-run -f DryRunFormatter', cucumber_opts(options[:test_options])].compact.join(" ")).split("\n")
          refined_tests =[]
          tests.delete_at(0) if tests[0].downcase.include?('using')
          tests.each do |test|
            refined_tests << test.gsub('\\','/')
          end
            $stdout << "The number of scenarios found to be executed: #{refined_tests.count}"
            $stdout << "\n"
            Grouper.in_groups(refined_tests, num_groups)
            #Grouper.in_even_groups_by_size(refined_tests, num_groups, options)
          #end
        end
      end
    end
  end
end
