# Examples of fetching the "last n per user" with lateral join

Have you ever needed to get the most recent N posts for each user in rails, but didn't know how to do it without using map?

Or maybe something similar like:

- The first or last X comments for each post
- The first or last Y payments for each customer
- The first or last Z reviews for each customer

Sometimes could be ok to just fetch all elements and filter with ruby, but sometimes it is not possible. Also it can cause n+1 queries if your are not careful.

Here I want to show you how you can solve this problem using a lateral join.

Check the [example.rb](example.rb) file.

## How to run the examples

1. **Install the dependencies** with `bundle install`.

2. **Run the examples** with `bundle exec run_playground example.rb`

## Active Record Playground Runner

This example uses the [Active Record Playground Runner](https://bhserna.com/active-record-playground-runner-introduction.html) by [bhserna](https://bhserna.com)