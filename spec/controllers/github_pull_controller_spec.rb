require 'spec_helper'

describe GithubPullController, :vcr => {} do
  before do
    @project = Factory(:project)
  end

  describe "accessed by a normal user" do
    before(:each) do
      authenticate(:user)
    end

    describe "forbidden actions" do

      it "should include POST create" do
        post :create, :project_id => @project
      end

      after do
        verify_authorization_unsuccessful
      end
    end
  end

  describe "accessed by an admin" do
    before do
      authenticate(:admin)
    end

    let :author do
      double(:author, :date => Time.now, :email => "some@where.com", :login => "somewhere")
    end

    let :commits do
      (1..3).map do
        double(:commit).as_null_object.tap do |commit|
          commit.stub(:author => author)
        end
      end
    end

    before :each do
      unless defined?(::API_KEYS)
        ::API_KEYS = {}
        ::API_KEYS.stub(:[]).with(:github) { 'xxxxx' }
      end
      Github::Client.any_instance.stub_chain(:repos, :commits, :all => commits)
    end

    describe "POST create" do
      let :github_project do
        Factory(:project, :github_url => "http://github.com/a_project/with_commits")
      end

      let :number_of_commits_in_repository do
        commits.length
      end

      it "should get git commits" do
        post :create, :project_id => github_project
        assigns(:github_pull).commits.count.should == number_of_commits_in_repository
      end

      it "should save them to the database, but not resave on a subsequent pull" do
        expect do
          post :create, :project_id => github_project
        end.to change{Activity.count}.by(number_of_commits_in_repository)
        expect do
          Activity.any_instance.should_not_receive(:save)
          post :create, :project_id => github_project
        end.to_not change{Activity.count}
      end
    end
  end
end
