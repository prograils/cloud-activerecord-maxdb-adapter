activerecord-maxdb-adapter
===========================

This is an ActiveRecord adapter for the SAP MaxDB database. It is intended to serve as an extension to
the ActiveRecord-JDBC adapter project, and thus it is usable on Java/JRuby only. Noteworthy parts are:

- `lib/arjdbc/discover.rb`: This file gets loaded by
  activerecord-jdbc-adapter, and where we register our extension.
- `lib/arjdbc/maxdb/adapter.rb`: Organize the ::ArJdbc::MaxDB code in here.
  In this module we define details for the SQL dialect, specific for MaxDB.
- `lib/arjdbc/maxdb/connection_methods.rb`: Here, the adapter figures out how to
  interpret database.yml configurations, that are targeted at it.
- `lib/active_record/connection_adapters/maxdb_adapter.rb`: This
  file is what allows ActiveRecord to load an adapter from its
  `adapter: maxdb` line in database.yml.
- `lib/arjdbc/maxdb.rb`: This file, apart from other stuff, requires the gem
  that carries the JDBC driver for MaxDB.

=============================
Dependencies:

This gem depends on the activerecord-jdbc-adapter gem, version >= 1.0.0, since this
is the version that introduces the discovery mechanism.

This gem depends on the gem that packages the JDBC driver for MaxDB: jdbc-maxdb.


=============================
Building the gem:

$> gem build activerecord-maxdb-adapter.gemspec


=============================
Installing the gem:

$> gem install activerecord-maxdb-adapter

# ActiveRecord JDBC adapter for SAP MaxDB database

## Overview

This is an ActiveRecord JDBC adapter for the [SAP MaxDB database](http://maxdb.sap.com/). It is intended to be used in JRuby environment
only and it is an extension of the [ActiveRecord JDBC Adapter project](https://github.com/jruby/activerecord-jdbc-adapter).

This gem requires the [jdbc-maxdb gem](https://github.com/sap/cloud-jdbc-maxdb-gem).

The adapter works for Rails 3. It uses [Arel](https://github.com/rails/arel) so it probably won't work with Rails 2.

To install the gem you would have to build it from source:

* `jruby -S gem build activerecord-maxdb-adapter.gemspec`
* `jruby -S gem install activerecord-maxdb-adapter`


To use the adapter add the following in your *database.yml* configuration:

    development:
    adapter: maxdb
    encoding: utf8
    reconnect: false
    host: <your_MaxDB_host>
    database: <your_MaxDB_database>
    pool: 5
    username: <your_MaxDB_user_name>
    password: <your_MaxDB_password>

JNDI setting is supported as well (this is coming from the generic AR-JDBC Adapter):

    production:
    adapter: maxdb
    encoding: utf8
    reconnect: false
    jndi: java:comp/env/jdbc/myMaxDBDataSource
    pool: 5



## Contributing

This is an open source project under the Apache 2.0 license, and every contribution is welcome. Issues, pull-requests and other discussions are welcome and expected to take place here.

## Wiki page

You can check [this wiki page](https://github.com/sap/cloud-activerecord-maxdb-adapter/wiki/Creating-ActiveRecord-JDBC-adapters) for more details of how we created this adapter.
