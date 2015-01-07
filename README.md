# Overview
The **pflgviewer** application is written based on Ruby on Rails 4 and Ruby 2. PostgreSQL is used as backend database.
The application is comprised of
* The front-end web application 
* The backend parser which runs periodically to import Postfix logs to the webapp's database

# Installation
### Install PostgreSQL
Version 9.2 or newer is required. Refer to [PostgreSQL Download Page](http://www.postgresql.org/download/)
### Install Ruby and Rails webapp
Install the latest Ruby by:
```sh
\curl -sSL https://get.rvm.io | bash -s stable --ruby
```
Make sure Ruby is installed to the current shell:
```sh
source ~/.rvm/scripts/rvm
```
Checkout the source folder `pflgviewer` to a desired location (`/home/user/pflgviewer` for example). Then change working directory to the source folder:
```sh
cd /home/user/pflgviewer
```
Then install Rails and the related stuffs:
```sh
bundle install
```
#### Initiate the database
Open the `[source]/config/database.yml` file and change the PostgreSQL parameters appropriately
Run the database initialization scripts
```sh
RAILS_ENV=production rake db:create
RAILS_ENV=production rake db:migrate
```
#### Start the Start the webapp's daemon process
We use a daemon process to facilitate data download. The daemon can be started by
```sh
RAILS_ENV=production ruby bin/delayed_job start
```
Check to make sure the daemon is running
```sh
RAILS_ENV=production ruby bin/delayed_job status
```
#### Start the webapp
Change working directory to the source folder and start the application on port 3000
```sh
cd /home/user/pflgviewer
RAILS_ENV=production rails s -p 3000 -d
```
Now open your web browser, go to `http://localhost:3000`. That's it!
## Install The Parser
The parser script is located at `[source]/lib/parser.rb`. It can be run by
```sh
DATABASE_URL=postgres://user:password@localhost/pflgviewerdb ruby parser.rb --path=/var/log --name=mail.log
```
With DATABSE_URL contains the credentials to the webapp's PostgreSQL database. Using the above command, the parser will search for all log files like:
```sh
/var/log/mail.log
/var/log/mail.log.1
/var/log/mail.log.2
...
```
to import the Postfix log entries into the webapp's database.

**Note** The parser can be configured as a cron job.

# Reference
Please contact Louis in case of any issue
