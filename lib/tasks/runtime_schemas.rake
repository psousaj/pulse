namespace :pulse do
  desc "Prepare runtime schemas for queue/cache/cable when development uses a single SQLite database"
  task prepare_runtime_schemas: :environment do
    prepared = Pulse::RuntimeSchemaPreparer.prepare!

    if prepared
      puts "Prepared runtime schemas in the current SQLite database."
    else
      puts "Runtime schemas already available or this environment uses dedicated runtime databases."
    end
  end
end
