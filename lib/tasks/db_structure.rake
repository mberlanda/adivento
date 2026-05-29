# pg_dump version skew: macOS Homebrew pg_dump may be newer than the server and
# emit settings (e.g. transaction_timeout) unknown to the server. Strip them so
# structure.sql loads cleanly regardless of the client/server version gap.
Rake::Task['db:schema:dump'].enhance do
  next unless Rails.application.config.active_record.schema_format == :sql

  path = Rails.root.join('db', 'structure.sql')
  content = path.read
  cleaned = content.gsub(/^SET transaction_timeout\s*=\s*\d+;\n?/, '')
  path.write(cleaned) if cleaned != content
end
