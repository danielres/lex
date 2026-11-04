defmodule AshAuthenticationDevUsers.Test.Secret do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        AshAuthenticationDevUsers.Test.User,
        _opts,
        _context
      ) do
    {:ok, "development-authentication-test-signing-secret"}
  end
end

defmodule AshAuthenticationDevUsers.Test.Token do
  use Ash.Resource,
    domain: AshAuthenticationDevUsers.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication.TokenResource]

  ets do
    private? true
  end

  actions do
    defaults [:read]

    read :expired do
      filter expr(expires_at < now())
    end

    read :get_token do
      get? true
      argument :token, :string, sensitive?: true
      argument :jti, :string, sensitive?: true
      argument :purpose, :string
      prepare AshAuthentication.TokenResource.GetTokenPreparation
    end

    action :revoked?, :boolean do
      argument :token, :string, sensitive?: true
      argument :jti, :string, sensitive?: true
      run AshAuthentication.TokenResource.IsRevoked
    end

    create :revoke_token do
      accept [:extra_data]
      argument :token, :string, allow_nil?: false, sensitive?: true
      change AshAuthentication.TokenResource.RevokeTokenChange
    end

    create :revoke_jti do
      accept [:extra_data]
      argument :subject, :string, allow_nil?: false, sensitive?: true
      argument :jti, :string, allow_nil?: false, sensitive?: true
      change AshAuthentication.TokenResource.RevokeJtiChange
    end

    create :store_token do
      accept [:extra_data, :purpose]
      argument :token, :string, allow_nil?: false, sensitive?: true
      change AshAuthentication.TokenResource.StoreTokenChange
    end

    destroy :expunge_expired do
      change filter(expr(expires_at < now()))
    end

    update :revoke_all_stored_for_subject do
      accept [:extra_data]
      argument :subject, :string, allow_nil?: false, sensitive?: true
      change AshAuthentication.TokenResource.RevokeAllStoredForSubjectChange
    end
  end

  attributes do
    attribute :jti, :string,
      primary_key?: true,
      allow_nil?: false,
      public?: true,
      sensitive?: true

    attribute :subject, :string, allow_nil?: false, public?: true
    attribute :expires_at, :utc_datetime, allow_nil?: false, public?: true
    attribute :purpose, :string, allow_nil?: false, public?: true
    attribute :extra_data, :map, public?: true
    create_timestamp :created_at
    update_timestamp :updated_at
  end
end

defmodule AshAuthenticationDevUsers.Test.User do
  use Ash.Resource,
    domain: AshAuthenticationDevUsers.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication, AshAuthenticationDevUsers.Strategy]

  ets do
    private? true
  end

  authentication do
    session_identifier :unsafe

    strategies do
      dev_users do
        identity(:unique_name)

        users(
          tom: %{name: "Tom", hue: 25},
          sandra: %{name: "Sandra", hue: 115}
        )
      end
    end

    tokens do
      enabled? true
      token_resource AshAuthenticationDevUsers.Test.Token
      signing_secret AshAuthenticationDevUsers.Test.Secret
      store_all_tokens? false
      require_token_presence_for_authentication? false
    end
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :hue, :integer, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_name, [:name], pre_check_with: AshAuthenticationDevUsers.Test.Domain
  end
end

defmodule AshAuthenticationDevUsers.Test.Domain do
  use Ash.Domain

  resources do
    resource AshAuthenticationDevUsers.Test.Token
    resource AshAuthenticationDevUsers.Test.User
  end
end
