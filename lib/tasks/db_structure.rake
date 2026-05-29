# Strip settings not supported by the Docker PostgreSQL server version
# (pg_dump on macOS 17+ emits transaction_timeout; server may be an older major).
Rake::Task['db:schema:dump'].enhance do
  next unless Rails.application.config.active_record.schema_format == :sql

  path = Rails.root.join('db', 'structure.sql')
  content = path.read
  cleaned = content.gsub(/^SET transaction_timeout\s*=\s*\d+;\n?/, '')
  path.write(cleaned) if cleaned != content
end
