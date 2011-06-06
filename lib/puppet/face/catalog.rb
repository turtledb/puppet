require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:catalog, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Compile, save, view, and convert catalogs."
  description <<-'EOT'
    This face primarily interacts with the compiling subsystem. By default,
    it compiles a catalog using the default manifest and the hostname from
    `certname`, but you can choose to retrieve a catalog from the server by
    specifying '--terminus rest'.  You can also choose to print any catalog
    in 'dot' format (for easy graph viewing with OmniGraffle or Graphviz)
    with '--render-as dot'.
  EOT

  get_action(:destroy).summary "Invalid for this face."
  get_action(:search).summary "Query format unknown; potentially invalid for this face."

  action(:apply) do
    summary "Apply a Puppet::Resource::Catalog object."
    description <<-'EOT'
      Finds and applies a catalog. This action takes no arguments, but
      the source of the catalog can be managed with the --terminus option.
    EOT
    returns <<-'EOT'
      A Puppet::Transaction::Report object.
    EOT
    examples <<-'EOT'
      Apply the locally cached catalog:

      $ puppet catalog apply --terminus yaml

      Retrieve a catalog from the master and apply it, in one step:

      $ puppet catalog apply --terminus rest

      From `secret_agent.rb` (API example):

          # ...
          Puppet::Face[:catalog, '0.0.1'].download
          # (Termini are singletons; catalog.download has a side effect of
          # setting the catalog terminus to yaml)
          report  = Puppet::Face[:catalog, '0.0.1'].apply
          # ...
    EOT

    when_invoked do |options|
      catalog = Puppet::Face[:catalog, "0.0.1"].find(Puppet[:certname]) or raise "Could not find catalog for #{Puppet[:certname]}"
      catalog = catalog.to_ral

      report = Puppet::Transaction::Report.new("apply")
      report.configuration_version = catalog.version

      Puppet::Util::Log.newdestination(report)

      begin
        benchmark(:notice, "Finished catalog run") do
          catalog.apply(:report => report)
        end
      rescue => detail
        puts detail.backtrace if Puppet[:trace]
        Puppet.err "Failed to apply catalog: #{detail}"
      end

      report.finalize_report
      report
    end
  end

  action(:download) do
    summary "Download this node's catalog from the puppet master server."
    description <<-'EOT'
      Retrieves a catalog from the puppet master and saves it to the
      local yaml cache. The saved catalog can be used in subsequent
      catalog actions by specifying '--terminus rest'.

      This action always contacts the puppet master and will ignore
      alternate termini.
    EOT
    returns "Nothing."
    notes <<-'EOT'
      As termini are singletons, this action has a side effect of
      exporting Puppet::Resource::Catalog.indirection.terminus_class =
      yaml to the calling context when used with the Ruby Faces API. The
      terminus must be explicitly re-set for subsequent catalog actions.
    EOT
    examples <<-'EOT'
      Retrieve and store a catalog:

      $ puppet catalog download

      From `secret_agent.rb` (API example):

          Puppet::Face[:plugin, '0.0.1'].download
          Puppet::Face[:facts, '0.0.1'].upload
          Puppet::Face[:catalog, '0.0.1'].download
          # ...
    EOT
    when_invoked do |options|
      Puppet::Resource::Catalog.indirection.terminus_class = :rest
      Puppet::Resource::Catalog.indirection.cache_class = nil
      catalog = nil
      retrieval_duration = thinmark do
        catalog = Puppet::Face[:catalog, '0.0.1'].find(Puppet[:certname])
      end
      catalog.retrieval_duration = retrieval_duration
      catalog.write_class_file

      Puppet::Resource::Catalog.indirection.terminus_class = :yaml
      Puppet::Face[:catalog, "0.0.1"].save(catalog)
      Puppet.notice "Saved catalog for #{Puppet[:certname]} to yaml"
      nil
    end
  end
end