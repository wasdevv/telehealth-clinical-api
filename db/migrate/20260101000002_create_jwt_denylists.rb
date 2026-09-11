class CreateJwtDenylists < ActiveRecord::Migration[8.1]
  def change
    # rubocop:disable Rails/CreateTableWithTimestamps -- a revocation row is written
    # once and never revised; `exp` is the only time that matters.
    create_table :jwt_denylists do |t|
      t.string :jti, null: false
      t.datetime :exp, null: false
    end

    add_index :jwt_denylists, :jti, unique: true
    # ExpiredTokenSweeper prunes by this index; without it the table only grows.
    add_index :jwt_denylists, :exp
    # rubocop:enable Rails/CreateTableWithTimestamps
  end
end
