require 'date'
require 'json'
require 'active_record'
require 'sqlite3'

# Set up a database that resides in RAM
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

# Set up database tables and columns
ActiveRecord::Schema.define do
  create_table "users" do |t|
    t.string   "name"
  end
  create_table "events" do |t|
    t.integer  "user_id"
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
  end
end

# Set up model classes
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class User < ApplicationRecord
  has_many :events
end

class Event < ApplicationRecord
  belongs_to :user

  def has_time_overlap?(start_range, end_range)
    start_range <= end_time && end_range >= start_time
  end

  def date_string
    start_time.to_date.to_s
  end
end

# Solution Logic
search_users = ARGV[0]&.split(",")
JSON.parse(File.read('users.json')).each { |user| User.create(id: user["id"], name: user["name"]) }
JSON.parse(File.read('events.json')).each { |event| Event.create(id: event["id"], user_id: event["user_id"], start_time: event["start_time"], end_time: event["end_time"]) }

filtered_users = User.where(name: search_users)
filtered_events = Event.where(user: filtered_users).order(:start_time)

# initialize busy timeline map
busy_timeline = {
  "2021-07-05" => [],
  "2021-07-06" => [],
  "2021-07-07" => []
}

current_date_key = "2021-07-05"
chunk_start = nil
chunk_end = nil

# events loop
filtered_events.each do |event|
  if chunk_start.nil? || chunk_end.nil? # first iteration
    chunk_start = event.start_time
    chunk_end = event.end_time
  end
  date_key = event.start_time.to_date.to_s

  next if event.start_time == chunk_start && event.end_time == chunk_end && current_date_key == date_key

  if current_date_key != date_key # if new day
    # create the final timeline chunk for the previous date
    busy_timeline[current_date_key] << { start: chunk_start, end: chunk_end }
    # reset variables to current event dates
    current_date_key = date_key
    chunk_start = event.start_time
    chunk_end = event.end_time
  else
    if event.has_time_overlap?(chunk_start, chunk_end) # extend current busy chunk range if there is a time overlap
      chunk_end = [event.end_time, chunk_end].max
    else # create the chunk if no overlap and reinitialize the next chunk with current event dates
      busy_timeline[current_date_key] << { start: chunk_start, end: chunk_end }
      chunk_start = event.start_time
      chunk_end = event.end_time
    end
  end
end

# create final busy time chunk
busy_timeline[current_date_key] << { start: chunk_start, end: chunk_end }

# return free timeline (inverse of busy timeline) per date
puts "------------------------"
puts ""
busy_timeline.each do |date_string, busy_chunk_array|
  chunk_start_time = "13:00"
  busy_chunk_array.each do |busy_chunk|
    chunk_end_time = busy_chunk[:start].strftime("%k:%M")
    if chunk_start_time == chunk_end_time
      chunk_start_time = busy_chunk[:end].strftime("%k:%M")
      next
    end
    puts "#{date_string} #{chunk_start_time} - #{chunk_end_time}"
    chunk_start_time = busy_chunk[:end].strftime("%k:%M")
  end
  chunk_end_time = "21:00"
  puts "#{date_string} #{chunk_start_time} - #{chunk_end_time}" if chunk_start_time != chunk_end_time
  puts ""
end
puts "------------------------"