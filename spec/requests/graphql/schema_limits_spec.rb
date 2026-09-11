require "rails_helper"

RSpec.describe "Schema limits", type: :request do
  let(:patient) { create(:patient) }

  it "refuses a query deeper than max_depth" do
    deep = <<~GQL
      { myAppointments { edges { node { doctor { user { patient { user { patient { user { patient { id } } } } } } } } } } }
    GQL

    body = graphql(deep, user: patient.user)

    expect(body["errors"].first["message"]).to match(/depth/i)
  end

  it "refuses a query that costs more than max_complexity" do
    body = graphql("{ myAppointments(first: 500) { edges { node { id } } } }", user: patient.user)

    expect(body["errors"].first["message"]).to match(/complexity/i)
  end

  it "clamps a page size larger than default_max_page_size" do
    doctor = create(:doctor)
    30.times do |_i|
      create(:appointment, patient: patient, availability: create(:availability, doctor: doctor), doctor: doctor)
    end

    body = graphql("{ myAppointments(first: 50) { edges { node { id } } } }", user: patient.user)

    expect(graphql_data(body, "myAppointments", "edges").size).to eq(25)
  end

  it "lets a realistic client query through" do
    body = graphql(<<~GQL, user: patient.user)
      query {
        me { id email role patient { fullName } }
        myAppointments(first: 25) {
          edges { node { id status startsAt endsAt externalRef
                         doctor { id fullName specialty }
                         patient { id fullName phone } } }
          pageInfo { hasNextPage endCursor }
        }
      }
    GQL

    expect(body["errors"]).to be_nil
  end
end
