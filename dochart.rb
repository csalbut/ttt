#!/usr/bin/ruby

require 'time'
require 'json'

# Command-line options parsing
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'

require './time_utils.rb'

class OptionParser

    def Time.yesterday; now - 86400; end

    # Return a structure describing the options.
    def self.parse(args)
        options = OpenStruct.new
        options.time_begin = Time.yesterday
        options.time_end = Time.now
        options.out_type = "pie"
        options.verbose = false

        opts = OptionParser.new do |opts|
            opts.banner = "Usage: #{$0} [options]"

            opts.separator ""
            opts.separator "Options:"

            opts.on("-b", "--tb", "--time-begin <TIME>", Time,
                    "Analyze only tasks since TIME. Format: '%Y-%m-%d %H:%M:%S %z'",
                    "Default: 24h ago. Example: '2013-09-24'") do |time|
                options.time_begin = time
            end

            opts.on("-e", "--te", "--time-end <TIME>", Time,
                    "Analyze only tasks before TIME. Format: '%Y-%m-%d %H:%M:%S %z'",
                    "Default: now. Example: '13:30'") do |time|
                options.time_end = time if !(time.nil?)
            end

            opts.on("-t", "--out-type [pie|cal]", String,
                    "Specify type of generated output.",
                    "'pie': piechart,",
                    "'cal': weekly calendar,") do |out_type|
                options.out_type = out_type
            end

            opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
                options.verbose = v
            end

            opts.on_tail("-h", "--help", "Show this message") do
                puts opts
                exit
            end

        end

        opts.parse!(args)
        options
    end  # parse()
end  # class OptionParser


class Task
    attr_accessor :name
    attr_reader :duration
    attr_reader :duration_str
    @timestamps

    include Comparable
    include TimeUtilities

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
        @duration_str = human_readable(@duration)
        @timestamps.push(last_timestamp)
    end

    def <=> (other)
        s = self.duration
        o = other.duration
        return  1 if s > o
        return -1 if s < o
        return  0 if s == o
    end

    def to_cal
        set_of_events = Array.new
        @timestamps.each do |timestamp|
            cal_item = CalItem.new
            cal_item.title = @name
            cal_item.time_start = timestamp[:start]
            cal_item.time_stop = timestamp[:stop]
            set_of_events.push(cal_item.get)
        end
        return set_of_events
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


class LogFileParser

    def parse(filename, time_begin, time_end)
        tasks = TaskSet.new
        logfile = File.open(filename, 'r')

        logfile.each do |line|
            log_entry = LogEntry.new(line)
            task_name = log_entry.get_name
            timestamp = log_entry.get_time_sec

            if (time_begin..time_end).cover? Time.at(timestamp)

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
        end

        return tasks
    end

end


class PieSlice
    attr_writer :label
    attr_writer :value

    def get
        return { :label => @label, :data => @value }
    end
end

class CalItem
    attr_writer :title
    attr_writer :time_start
    attr_writer :time_stop

    def get
        return { :title => @title, :start => @time_start * 1000, :end => @time_stop * 1000 }
    end
end

class TaskSet

    @tasks

    include Enumerable

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

    def each
        @tasks.each { |task| yield task }
        return @tasks
    end

    def sort!
        @tasks = self.sort
    end

    def reverse!
        @tasks = @tasks.reverse
    end

    def to_json_piechart
        piechart = Array.new
        @tasks.each do |task|
            slice = PieSlice.new
            slice.label = "[" + task.duration_str.chop + "] " + task.name

            slice.value = task.duration
            piechart.push(slice.get)
        end
        return JSON.pretty_generate(piechart)
    end

    def to_json_calendar
        calendar = Array.new
        @tasks.each do |task|
                calendar.push(task.to_cal)
        end
        return JSON.pretty_generate(calendar.flatten)
    end

    def dbg_print
        puts "Task set --------"
        puts("Number of tasks: " + @tasks.length.to_s)
        puts to_json_piechart
        puts "-----------------"
    end

    def print_last
        puts(@tasks[1].to_s + "\n")
    end

end


options = OptionParser.parse(ARGV)
tasks = LogFileParser.new.parse("wintt.txt", options.time_begin, options.time_end)
tasks.sort!.reverse!

case options.out_type
when "pie"
    puts(tasks.to_json_piechart)
when "cal"
    puts(tasks.to_json_calendar)
else
    puts("Error: output type not specified")
end

