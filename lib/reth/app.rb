# -*- encoding : ascii-8bit -*-

module Reth

  class App < ::DEVp2p::App

    default_config(
      client_version_string: CLIENT_VERSION_STRING,
      deactivated_services: [],
      post_app_start_callback: nil
    )

  end

end
