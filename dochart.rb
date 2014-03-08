#!/usr/bin/ruby

require 'time'
require 'json'

class Task
    attr_accessor :name
    attr_reader :duration
    @timestamps

    def initialize
        @name = ''
        @timestamps = Array.new
        @duration = 0
    end

    def initialize(name)
        @name = name
        @timestamps = Array.new
        @duration = 0
    end

    def add_start_time(seconds)
        @timestamps.push( {:start => seconds, :stop => seconds} )
    end

    def add_stop_time(seconds)
        last_timestamp = @timestamps.pop
        last_timestamp[:stop] = seconds
        @duration += last_timestamp[:stop] - last_timestamp[:start]
        @timestamps.push(last_timestamp)
    end

    def dbg_print
        puts('Task name: ' + @name)
        puts('duration: ' + @duration.to_s)
        puts(@timestamps)
        puts '-----'
    end
end

class LogEntry
    @raw_line

    def initialize(raw_line)
        @raw_line = raw_line
    end

    def start?
        @raw_line.include? '[start]'
    end

    def stop?
        @raw_line.include? '[stop]'
    end

    def get_name
        name_words = @raw_line.split[3..-3]
        name = ''
        name_words.each {|word| name += word + ' '}
        name.chop!
        return name
    end

    def get_time_sec
        str_date = @raw_line.split[0]
        str_time = @raw_line.split[1]

        str_date = date_str_convert(str_date)

        time = Time.parse(str_date + ' ' + str_time)
        time_sec = time.to_i
        return time_sec
    end

    def date_str_convert(date)
        day = date[0..1]
        month = date[3..4]
        year = date[6..9]
        return year + '-' + month + '-' + day
    end

    private :date_str_convert
end

class PieSlice
    attr_writer :label
    attr_writer :value

    def get
        return { :label => @label, :data => @value }
    end
end

class TaskSet

    @tasks

    def initialize
        @tasks = Array.new
    end

    def include?(task_name)
        @tasks.each do |task|
            if task.name == task_name
                return true
            end
        end

        return false
    end

    def add(task)
        if self.include?(task.name)
            index = @tasks.index(task)
            @tasks[index] = task
        else
            @tasks.push(task)
        end
    end

    def get(task_name)
        @tasks.each do |task|
            if task.name == task_name
                return task
            end
        end

        return nil
    end

    def to_json
        piechart = Array.new
        @tasks.each do |task|
            slice = PieSlice.new
            slice.label = task.name
            slice.value = task.duration
            piechart.push(slice.get)
        end
        return JSON.pretty_generate(piechart)
    end

    def dbg_print
        puts "Task set --------"
        puts("Number of tasks: " + @tasks.length.to_s)
        puts to_json
        puts "-----------------"
    end

    def print_last
        puts(@tasks[1].to_s + "\n")
    end

end


tasks = TaskSet.new
logfile = File.open('wintt.txt', 'r')

logfile.each do |line| 
    log_entry = LogEntry.new(line)
    task_name = log_entry.get_name
    timestamp = log_entry.get_time_sec

    if log_entry.start?

        if tasks.include?(task_name)
            #puts 'Hey, I know this task! : ' + task_name
            task = tasks.get(task_name)
        else
            task = Task.new(task_name)
        end

        task.add_start_time(timestamp.to_i)
        tasks.add(task)

    elsif log_entry.stop?

        if tasks.include?(task_name)
            #puts 'Hey, I know this task! : ' + task_name
            task = tasks.get(task_name)
            task.add_stop_time(timestamp.to_i)
        else
            puts 'Error! Encountered [stop] marker without corresponding [start].'
        end
    end
end

piechart_file = File.open('tasks_piechart.json', 'w')
piechart_file.puts(tasks.to_json)
piechart_file.close

