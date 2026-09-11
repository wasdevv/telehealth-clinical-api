require "rails_helper"

# Guards requirement 2: without batch_belongs_to these queries grow one SELECT per row.
RSpec.describe "Batched associations", type: :request do
  let(:admin) { create(:user, :admin) }

  def select_count_while(&)
    queries = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      queries += 1 unless payload[:name].in?(%w[SCHEMA
                                                TRANSACTION]) || payload[:sql].start_with?("BEGIN", "COMMIT", "ROLLBACK")
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    queries
  end

  it "resolves doctor and patient for many appointments in a bounded number of queries" do
    10.times do
      doctor = create(:doctor)
      create(:appointment, patient: create(:patient), availability: create(:availability, doctor: doctor), doctor: doctor)
    end

    query = "{ myAppointments { edges { node { id doctor { fullName user { email } } patient { fullName user { email } } } } } }"

    count = select_count_while { graphql(query, user: admin) }

    # One for the user behind the token, one for the appointments page, one per batched
    # association level. Ten appointments must not cost ten lookups each.
    expect(count).to be < 15
  end
end
