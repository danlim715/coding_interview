# Background

Most calendar applications provide some kind of "meet with" feature where the user
can input a list of coworkers with whom they want to meet, and the calendar will
output a list of times where all the coworkers are available.

For example, say that we want to schedule a meeting with Jane, John, and Mary on Monday.

- Jane is busy from 9am - 10am, 12pm - 1pm, and 4pm - 5pm.
- John is busy from 9:30am - 11:00am and 3pm - 4pm
- Mary is busy from 3:30pm - 5pm.

Based on that information, our calendar app should tell us that everyone is available:
- 11:00am - 12:00pm
- 1pm - 3pm

We can then schedule a meeting during any of those available times.


# Instructions

Given the data in `events.json` and `users.json`, build a script that displays available times
for a given set of users. For example, your script might be executed like this:

```
python availability.py Maggie,Joe,Jordan
```

and would output something like this:

```
2021-07-05 13:30 - 16:00
2021-07-05 17:00 - 19:00
2021-07-05 20:00 - 21:00

2021-07-06 14:30 - 15:00
2021-07-06 16:00 - 18:00
2021-07-06 19:00 - 19:30
2021-07-06 20:00 - 20:30

2021-07-07 14:00 - 15:00
2021-07-07 16:00 - 16:15
```


For the purposes of this exercise, you should restrict your search between `2021-07-05` and `2021-07-07`,
which are the three days covered in the `events.json` file. You can also assume working hours between
`13:00` and `21:00` UTC, which is 9-5 Eastern (don't worry about any time zone conversion, just work in
UTC). Optionally, you could make your program support configured working hours, but this is not necessary.


## Data files

### `users.json`

A list of users that our system is aware of. You can assume all the names are unique (in the real world, maybe
they would be input as email addresses).

`id`: An integer unique to the user

`name`: The display name of the user - your program should accept these names as input.

### `events.json`

A dataset of all events on the calendars of all our users.

`id`: An integer unique to the event

`user_id`: A foreign key reference to a user

`start_time`: The time the event begins

`end_time`: The time the event ends


# Notes

- Feel free to use whatever language you feel most comfortable working with
- Please provide instructions for execution of your program
- Please include a description of your approach to the problem, as well as any documentation about
  key parts of your code.
- You'll notice that all our events start and end on 15 minute blocks. However, this is not a strict
  requirement. Events may start or end on any minute (for example, you may have an event from 13:26 - 13:54).

# My Solution

## Run Instructions

To execute the code, run the following command on the console:
```
rails main.rb Maggie,Joe,Jordan
``` 
The list of users must be comma separated with no spaces.

## Description of Approach

I initially started off with a pure Ruby solution, but after some time, it felt strange using Ruby without the context of some Rails magic. In addition, querying data programatically didn't really seem ideal, so I spent some time setting up boilerplate code to initialize an in-memory database, database schema, and some models with associations. I figured this approach would also better showcase how I would do things in a real-life situation.

Once the boilerplate code setup was finished, I considered a couple of different solutions to solve this problem. My initial thought was to try and create an `open_timeline` hash where the key was the date string (hard-coded to `2021-07-05`, `2021-07-06`, or `2021-07-07`), and the value was an array of hashes that corresponded to "chunks" of free time between all meeting participants. I would initialize these values with arrays that contained a single hash: `{ start: 13:00, end: 21:00 }`. Then I would iterate through each of the existing events and split the chunks into subchunks according to the start and end times of each event, until I'm left with all the remaining fragments of free time. After stepping through some scenarios though, I realized the logic would get a bit complicated when having to remove multiple fragments of free time at once (as a result of coming across a long event after a series of shaving away short events) so I decided to try and find a different solution.

I considered other approaches like first sorting the events by length of time from longest to shortest instead of a specific date/time, or initializing an array with 480 entries (8 hour x 60 minutes), each represent a minute time increment for every minute between 13:00 and 21:00 and marking the busy minutes as I iterate through the list of existing events. Ultimately I settled on a solution that was similar in approach to my initial idea, but instead of trying to shave away, I would build up chunks of "busy time blocks" and then print the inverse of the busy chunks to get the free time slots. The logic to build up busy blocks seemed simpler than figuring out which blocks would need to be shaved down, since I wouldn't need to keep track of multiple different indices at a time. I also liked this solution because it would only have linear time complexity.

I start with sorting the list of filtered events by start date/time in ascending order. I then define `chunk_start` and `chunk_end` variables to keep track chunks of continuous busy time slots. I also keep track of a `current_date_key` variable, to keep track of which date's timeline I'm processing at any given moment. The other detail I added was a way to determine if an event's duration overlapped with any given date/time range. As I iterate through the list of events, I check if each event's start/end time overlap with the `chunk_start` and `chunk_end` time range I'm keeping track of. If they do overlap, I shift the `chunk_end` date later while keeping the `chunk_start` the same. Since I sorted the list of events by `start_time`, I only need to shift the `chunk_end` time to the later time, because the `start_time` of any event will never be earlier than any event preceeding it in the list. If at any point, the current event's times don't overlap with the `chunk_start` and `chunk_end` date range, I finalize/create the chunk, append it to corresponding date's busy timeline array, and re-initialize the next chunk's boundaries with the current event's start/end times. I also make sure to finalize/create a chunk if the `current_date_key` ever changes to a diferent day and again after the last iteration of the event_list loop. Once I'm done creating my "busy timeline hash", I simply iterate through each key value pair and print the inverse blocks of time starting at `13:00` and ending at `21:00`. The only thing I had to add here was a conditional preventing zero-length time blocks from printing to the console (which would happen if a busy time block starts at `13:00` or ends at `21:00`).