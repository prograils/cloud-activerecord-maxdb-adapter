require 'arel/visitors/maxdb'

module ::ArJdbc
  module MaxDB
    # This defines an Arel visitor for the adapter.
    # See https://github.com/jruby/activerecord-jdbc-adapter/issues/137
    def self.arel2_visitors(_config)
      { 'jdbc' => ::Arel::Visitors::MaxDB }
    end

    # Along with each newly created table, we need a corresponding sequence
    # for primary key generation.
    def create_table(name, options = {})
      super(name, options)
      execute("CREATE SEQUENCE #{default_sequence_name(name)} START WITH 1 INCREMENT BY 1")
    end

    # ... and we need to take care for the clean up.
    def drop_table(name)
      super(name)
      execute("DROP SEQUENCE #{default_sequence_name(name)}")
    end

    def rename_table(name, new_name)
      execute("RENAME TABLE #{name} TO #{new_name}")
      seq = default_sequence_name(name)
      new_seq = default_sequence_name(new_name)
      next_val = next_sequence_value(seq)
      execute("CREATE SEQUENCE #{new_seq} START WITH #{next_val} INCREMENT BY 1")
      execute("DROP SEQUENCE #{seq}")
    end

    # This gives the names we assign to sequences.
    def default_sequence_name(table_name, _primary_key = nil)
      "#{table_name}_seq"
    end

    # Get the next value from the sequence.
    # See http://maxdb.sap.com/doc/7_8/44/e15c6499fc03fde10000000a1553f6/content.htm
    def next_sequence_value(sequence_name)
      execute("SELECT #{sequence_name}.NEXTVAL id FROM DUMMY").first['id'].to_i
    end

    def modify_types(tp)
      tp[:primary_key] = 'INTEGER NOT NULL PRIMARY KEY'
      tp[:string] = { name: 'VARCHAR', limit: 255 }
      tp[:text] = { name: 'VARCHAR', limit: 5000 }
      tp[:integer] = { name: 'INTEGER', limit: nil }
      tp[:boolean]     = { name: 'TINYINT', limit: nil }
      tp
    end

    def add_column_options!(sql, options)
      options.delete(:default) if options.key?(:default) && options[:default].nil?
      sql << " DEFAULT #{quote(options.delete(:default))}" if options.key?(:default)
      super
    end

    def add_column(table_name, column_name, type, options = {})
      # The keyword COLUMN allows to use reserved names for columns (ex: date)
      column = "#{column_name} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
      add_column_options!(column, options)
      add_column_sql = "ALTER TABLE #{table_name} ADD (#{column})"
      execute(add_column_sql)
    end

    def change_column(table_name, column_name, type, options = {})
      type_sql = type_to_sql(type,
                             options[:limit],
                             options[:precision],
                             options[:scale])
      statement = "ALTER TABLE #{table_name} ALTER (#{column_name} #{type_sql})"
      execute(statement)
    end

    def change_column_default(table_name, column_name, default)
      column = column_for(table_name, column_name)
      change_column table_name, column_name, column.sql_type, default: default
    end

    def remove_column(table_name, column_name, _type = nil, _options = {})
      execute "ALTER TABLE #{table_name} DROP (#{column_name})"
    end

    # Handle correctly some boolean literals.
    def quote(value, column = nil)
      return value.quoted_id if value.respond_to?(:quoted_id)
      if column && column.respond_to?(:primary) && column.primary && column.klass != String
        return value.to_i.to_s
      end
      case value
      when TrueClass then '1'
      when FalseClass then '0'
      else super
      end
    end

    # The default generated index names can be too long for MaxDB, so we override the add_index method
    # and use the idx_tableName_columnName pattern for naming the indexes.

    def add_index(table_name, column_name, options = {})
      # In case the index is a composite one, the column_name argument is an
      # array of all the column names that constitute the index
      if column_name.is_a? (Array)
        suffix_name = column_name.join('_')
        column_list = column_name.join(', ')
      else
        suffix_name = column_name
        column_list = column_name
      end

      index_name = 'idx_' + "#{table_name}" + '_' + "#{suffix_name}"

      statement = 'CREATE'
      statement << ' UNIQUE ' if options[:unique]
      statement << ' INDEX ' + index_name[0..30]  # cut out the index name in case it becomes too long
      statement << " ON #{table_name}(#{column_list})"
      execute statement
    end

    def change_column_null(table_name, column_name, null)
      if null
        execute "ALTER TABLE #{table_name} ALTER (#{column_name} NULL)"
      else
        execute "ALTER TABLE #{table_name} ALTER (#{column_name} NOT NULL)"
      end
    end

    # We use eagerly prefetching of primary keys in order to get ActiveRecord synced with the auto generated primary key
    # in the database.
    def prefetch_primary_key?(_table_name = nil)
      true
    end

    def adapter_name
      'maxdb'
    end

    # Get the name of the user schema. Most of the times this would be the value of the 'username' in the
    # configuration. But we support a dedicated 'schema' field as well.
    def maxdb_schema
      if @config[:schema]
        @config[:schema].to_s
      elsif @config[:username]
        @config[:username].to_s
      end
    end

    # Restrict this metadata query to the schema of the user.
    def tables
      @connection.tables(nil, maxdb_schema)
    end

    # Restrict this metadata query to the schema of the user. This fixes the problem of failing INSERTs
    # which mix the columns of the application table USERS and MaxDB's system table DOMAIN.USERS
    def columns(table_name, name = nil)
      @connection.columns_internal(table_name.to_s, name, maxdb_schema)
    end

    # Executes an insert statement in the context of this connection.
    # @param sql the query string (or AREL object)
    # @param name logging marker for the executed SQL statement log entry
    # @param binds the bind parameters
    # @override available since **AR-3.1**
    def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
      if sql.respond_to?(:to_sql)
        sql = to_sql(sql, binds); to_sql = true
      end
      if prepared_statements?
        log(sql, name || 'SQL', binds) { @connection.execute_update(sql, binds) }
      else
        sql = suble_binds(sql, binds) unless to_sql # deprecated behavior
        log(sql, name || 'SQL') { @connection.execute_update(sql) }
      end
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    # Metadata model for a MaxDB column.
    class MaxDBColumn < JdbcColumn
      # The default value of a primary key column is a very strange string, which eventually becomes a zero - 0 -
      # for ActiveRecord. But we have to use 'nil' so that ActiveRecord fetches the newly generated pk value when
      # an INSERT statement has been executed.
      def default_value(val)
        if String === val && val.include?('DEFAULT SERIAL')
          nil
        else
          val
        end
      end
    end

    class MaxDBSQLAdapter < JdbcAdapter
      include ArJdbc::MaxDB

      def jdbc_column_class
        ActiveRecord::ConnectionAdapters::MaxDBColumn
      end
    end
  end
end
