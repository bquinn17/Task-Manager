require "rubygems"
require "active_record"
require "active_support"

module EarGTD
  
  module_function

  def destroy
    Models::Task.destroy_all
    Models::Project.destroy_all
    Models::Context.destroy_all
  end

  def add_task(description)
    
    task_desc = parse_task(description)
    task = Models::Task.create(:description => task_desc)

    if (project=parse_project(description))
      Models::Project.find_or_create_by_name(project).tasks << task
    end

    if (context=parse_context(description))
      Models::Context.find_or_create_by_name(context).tasks << task
    end

  end

  def remove_task(id)
    Models::Task.delete(id)
  end

  def tasks
    Models::Task.find(:all).map(&:to_s)
  end   
  
  def tasks_for_project(project)
    Models::Project.find_by_name(project).tasks.map(&:to_s)
  end   
  
  def tasks_for_context(context)
    Models::Context.find_by_name(context).tasks.map(&:to_s)
  end

  def dump(file=nil)
    content = Models::Task.dump
    if file
      File.open(file,"w") { |f| f.puts(content) }
    end
    return content
  end

  def import(string)
    string.each { |e| Models::Task.create(:description => e.chomp) }
  end

  def parse_project(string)
    string =~ /<(.*)>/ && $1.strip
  end

  def parse_task(string)
    string.gsub(/[<\[].*[>\]]/,"").strip
  end

  def parse_context(string)
    string =~ /\[(.*)\]/ && $1.strip
  end

  def process_command(cmd)
    args = Array(cmd)
    command = args.shift
    case(command)
    when "setup_db"
      EarGTD::Models.generate_schema
    when "+"
      add_task(args[0])
    when "@"
      t = tasks 
      puts t.empty? ? "Looks like you have nothing to do.\n" : t 
    when "@p"
      r = tasks_for_project(args[0]) rescue "Got nothing for #{args[0]}"
      puts r 
    when "@c"
      r = tasks_for_context(args[0]) rescue "Got nothing for #{args[0]}"
      puts r   
    when "-"
      remove_task(args[0].to_i)
    when "dump"
      c = dump(args[0])
      return if args[0]
      puts c
    when "destroy"
      destroy
    when "import"
      import(File.read(args[0]))
    else
      puts "Que?"
    end
    
  end  
  
  def connect(dbfile="data/ear_gtd.db")
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3", :database => dbfile
    )
  end

  module Models
    class Task < ActiveRecord::Base

      belongs_to :context
      belongs_to :project

      def to_s
        "#{id}. " << record_text 
      end

      def self.dump
        find(:all).map(&:record_text)
      end 
      
      def record_text
        ["#{description}",project,context].compact.join(" ")
      end

    end

    class Project < ActiveRecord::Base
      has_many :tasks

      def to_s; "<#{name}>"; end
    end

    class Context < ActiveRecord::Base
      has_many :tasks
      
      def to_s; "[#{name}]"; end
    end

    module_function
    
    def generate_schema
      ActiveRecord::Schema.define do 
        create_table :tasks do |t|
          t.column :description, :string
          t.column :status, :string
          t.column :context_id, :integer
          t.column :project_id, :integer
        end

        create_table :contexts do |t|
          t.column :name, :string
        end

        create_table :projects do |t|
          t.column :name, :string
        end
      end
    end

  end

end
