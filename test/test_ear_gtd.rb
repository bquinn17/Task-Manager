require "lib/ear_gtd"
require "test/unit"
require "spec-unit"
require "mocha"

class TestEarGTD < Test::Unit::TestCase

  TEST_DB = "data/test_ear_gtd.db"

  def self.prepare_database
    require "fileutils"
    FileUtils.rm TEST_DB  
    EarGTD.connect(TEST_DB)
    unless EarGTD::Models::Task.table_exists?
      EarGTD::Models.generate_schema
    end
  end

  include SpecUnit

  context "when defining schema" do

    def setup_mock_schema
      ActiveRecord::Schema.expects(:define)
    end
    
    def specify_setup_db_should_run_schema_define
      setup_mock_schema
      EarGTD.process_command("setup_db")
    end

  end

  prepare_database

  context "when manipulating tasks" do

    def setup
      @task_model = EarGTD::Models::Task
      @task_model.destroy_all       
      EarGTD::Models::Project.destroy_all
      EarGTD::Models::Context.destroy_all
      @message = " do the foo < protocol 4 > [context]"
    end
      

    context "when adding tasks" do

      def specify_adding_task_should_increase_total_count
        count = @task_model.count
        EarGTD.add_task "foo"
        assert_equal(count + 1, @task_model.count)
      end

      def specify_adding_task_with_project_increases_total_count
        count = @task_model.count
        EarGTD.add_task "foo <school>"
        assert_equal(count + 1, @task_model.count)
      end

      def specify_adding_task_with_context_increases_total_count
        count = @task_model.count
        EarGTD.add_task "foo [context]"
        assert_equal(count + 1, @task_model.count)
      end

      def specify_task_parses_correctly
        expected = "do the foo"
        assert_equal expected, EarGTD.parse_task(@message)
      end

      def specify_project_parses_correctly
        expected = "protocol 4"
        assert_equal expected, EarGTD.parse_project(@message)
      end

      def specify_project_nil_when_missing
        assert_nil EarGTD.parse_project("apple tree")
      end

      def specify_context_nil_when_missing
        assert_nil EarGTD.parse_context("apple tree")
      end

      def specify_context_parses_correctly
        expected = "context"
        assert_equal expected, EarGTD.parse_context(@message)
      end

      context "when using the + command" do

        def specify_process_command_should_forward_to_add_task
          EarGTD.expects(:add_task).with("something")
          EarGTD.process_command(["+","something"])
        end

      end

    end

    context "when listing tasks" do

      def setup
        @task_model.create(:description => "foo")
        @task_model.create(:description => "bar")
      end

      def specify_should_list_description_and_id
        expected = ["1. foo", "2. bar"]
        actual = EarGTD.tasks
        assert_equal expected, actual
      end

      def specify_should_return_empty_array_when_list_empty
        @task_model.destroy_all
        assert_equal [], EarGTD.tasks
      end
      
      context "when using the @ command" do

        def specify_process_command_should_output_tasks
          EarGTD.expects(:puts).with(EarGTD.tasks)
          EarGTD.process_command("@")
        end

        def specify_command_should_output_message_when_empty
          @task_model.destroy_all
          EarGTD.expects(:puts).with("Looks like you have nothing to do.\n")
          EarGTD.process_command("@")
        end

      end
      
    end

    context "when listing tasks by project" do
      
      def setup
        p1 = EarGTD::Models::Project.create(:name => "foo")
        p2 = EarGTD::Models::Project.create(:name => "bar")     
           
                     
        tasks = %w[apple banana strawberry pear].inject({}) do |s,d|
          s.merge(d => @task_model.create(:description => d))
        end                              
        
        p1.tasks << tasks["apple"] << tasks["pear"]
        p2.tasks << tasks["banana"]        
      end    
      
      def specify_should_limit_list_to_given_project
         expected = ["1. apple <foo>", "4. pear <foo>"] 
         actual = EarGTD.tasks_for_project("foo") 
         
         assert_equal expected, actual
      end 
      
      context "when using the @p command" do

        def specify_process_command_should_output_tasks
          EarGTD.expects(:puts).with(EarGTD.tasks_for_project("bar"))
          EarGTD.process_command(["@p","bar"])
        end 
                                                                 
      end 
      
      context "when listing tasks by context" do

        def setup
          c1 = EarGTD::Models::Context.create(:name => "foo")
          c2 = EarGTD::Models::Context.create(:name => "bar")     


          tasks = %w[apple banana strawberry pear].inject({}) do |s,d|
            s.merge(d => @task_model.create(:description => d))
          end                              

          c1.tasks << tasks["apple"] << tasks["pear"]
          c2.tasks << tasks["banana"]        
        end    

        def specify_should_limit_list_to_given_project
           expected = ["5. apple [foo]", "8. pear [foo]"] 
           actual = EarGTD.tasks_for_context("foo") 

           assert_equal expected, actual
        end 

        context "when using the @p command" do

          def specify_process_command_should_output_tasks
            EarGTD.expects(:puts).with(EarGTD.tasks_for_context("bar"))
            EarGTD.process_command(["@c","bar"])
          end 

        end 
      end
      
    end

    context "when removing tasks" do

      def setup
        @task_model.create(:description => "foo")
        @task_model.create(:description => "bar")
      end

      def specify_list_should_decrease_when_tasks_removed
        count = @task_model.count
        EarGTD.remove_task(2)
        assert_equal count - 1, @task_model.count
      end 

      def specify_should_be_able_to_empty_list
        assert_equal @task_model.count, 2

        EarGTD.remove_task(2)
        EarGTD.remove_task(1)

        assert @task_model.count.zero? 
      end

      context "when using the - command" do

        def specify_command_should_forward_to_remove_task
          EarGTD.expects(:remove_task).with(2)
          EarGTD.process_command(["-","2"])
        end

      end

    end

    context "when dumping tasks" do

      def setup
        %w[foo bar baz].each { |d| @task_model.create(:description => d) }
      end

      def setup_file_mock
        file = mock("file_handle")
        file.expects(:puts).with(["foo","bar","baz"])
        File.expects(:open).with("foo.txt","w").yields(file)
      end

      def specify_dump_should_give_array_of_descriptions
        expected = %w[foo bar baz]
        assert_equal expected, EarGTD.dump
      end

      def specify_dump_should_write_to_file_if_option_given
        setup_file_mock
        EarGTD.dump("foo.txt")
      end
      
      context "when using the dump command" do

        def specify_command_should_print_dumped_results_with_no_option
          EarGTD.expects(:puts).with(EarGTD.dump)
          EarGTD.process_command("dump") 
        end

        def specify_command_should_write_to_file_if_given_argument
          setup_file_mock
          EarGTD.process_command(["dump","foo.txt"])
        end

      end

    end

    context "when clearing tasks" do
      def setup
        %w[foo bar baz].each { |d| @task_model.create(:description => d) }
      end

      def specify_destroy_should_kill_all_tasks
        assert_equal 3, @task_model.count
        EarGTD.destroy
        assert @task_model.count.zero?
      end

      context "when using the destroy command" do

        def specify_command_is_forwarded_to_destroy_method
          EarGTD.expects(:destroy)
          EarGTD.process_command("destroy")
        end

      end
    end

    context "when importing tasks" do

      def specify_import_should_create_one_task_per_line
        EarGTD.import("apple\nbanana\nstrawberry\npeanuts\n")
        assert_equal 4, @task_model.count
      end

      def specify_import_should_strip_newlines_from_descriptions
        EarGTD.import("apple\nbanana\nstrawberry\npeanuts\n")
        %w[apple banana strawberry peanuts].each_with_index do |e,i|
          assert_equal e, @task_model.find(i+1).description
        end
      end

      context "when using the import command" do

        def specify_command_should_accept_file_and_forward_to_import
          File.expects(:read).with("foo.txt").returns("apple\nbanana\n")
          EarGTD.expects(:import).with("apple\nbanana\n")
          EarGTD.process_command(["import","foo.txt"])
        end

      end   

    end

    context "when given an unknown command" do

      def specify_should_print_error_message
        EarGTD.expects(:puts).with("Que?")
        EarGTD.process_command("something")
      end

    end    
    
    
  end
end
