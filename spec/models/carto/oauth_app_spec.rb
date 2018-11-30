# encoding: utf-8

require 'spec_helper_min'

module Carto
  describe OauthApp do
    describe '#validation' do
      before(:all) do
        @user = FactoryGirl.build(:carto_user)
      end

      it 'requires user if sync with central' do
        app = OauthApp.new
        expect(app).to_not(be_valid)
        expect(app.errors[:user]).to(include("can't be blank"))
      end

      it 'requires name' do
        app = OauthApp.new
        expect(app).to_not(be_valid)
        expect(app.errors[:name]).to(include("can't be blank"))

        app.name = ''
        expect(app).to_not(be_valid)
        expect(app.errors[:name]).to(include("can't be blank"))
      end

      it 'requires icon_url' do
        app = OauthApp.new
        expect(app).to_not(be_valid)
        expect(app.errors[:icon_url]).to(include("can't be blank"))

        app.icon_url = ''
        expect(app).to_not(be_valid)
        expect(app.errors[:icon_url]).to(include("can't be blank"))
      end

      describe 'redirection uri' do
        it 'rejected if empty' do
          app = OauthApp.new
          expect(app).to_not(be_valid)
          expect(app.errors[:redirect_uris]).to(include("can't be blank"))
        end

        it 'rejected if invalid' do
          app = OauthApp.new(redirect_uris: ['"invalid"'])
          expect(app).to_not(be_valid)
          expect(app.errors[:redirect_uris]).to(include('must be valid'))
        end

        it 'rejected if non-absolute' do
          app = OauthApp.new(redirect_uris: ['//wadus.com/path'])
          expect(app).to_not(be_valid)
          expect(app.errors[:redirect_uris]).to(include('must be absolute'))

          app = OauthApp.new(redirect_uris: ['/some_path'])
          expect(app).to_not(be_valid)
          expect(app.errors[:redirect_uris]).to(include('must be absolute'))
        end

        it 'rejected if non-https' do
          app = OauthApp.new(redirect_uris: ['http://wadus.com/path'])
          expect(app).to_not(be_valid)
          expect(app.errors[:redirect_uris]).to(include('must be https'))

          app = OauthApp.new(redirect_uris: ['file://some_path'])
          expect(app).to_not(be_valid)
          expect(app.errors[:redirect_uris]).to(include('must be https'))
        end

        it 'rejected if has fragment' do
          app = OauthApp.new(redirect_uris: ['https://wad.us/?query#fragment'])
          expect(app).to_not(be_valid)
          expect(app.errors[:redirect_uris]).to(include('must not contain a fragment'))
        end

        it 'accepted if valid' do
          app = OauthApp.new(redirect_uris: ['https://wad.us/path?query=value'])
          app.valid?
          expect(app.errors[:redirect_uris]).to(be_empty)
        end
      end

      it 'accepts if valid' do
        app = OauthApp.new(user: @user, name: 'name', redirect_uris: ['https://re.dir'], icon_url: 'some.png')
        expect(app).to(be_valid)
      end

      it 'accepts with no user' do
        app = OauthApp.new(name: 'name',
                           redirect_uris: ['https://re.dir'],
                           icon_url: 'some.png')
        expect(app).to(be_valid)
      end

      it 'accepts restricted without organization if user is not present in cloud' do
        app = Carto::OauthApp.new(name: 'name',
                                  redirect_uris: ['https://re.dir'],
                                  icon_url: 'some.png',
                                  restricted: true)
        expect(app).to(be_valid)
      end
    end

    context 'Central sync' do
      before(:all) do
        @user_oauth = FactoryGirl.create(:carto_user)
      end

      before(:each) do
        Cartodb::Central.stubs(:sync_data_with_cartodb_central?).returns(false)
        @oauth_app = FactoryGirl.create(:oauth_app, user: @user_oauth, avoid_sync_central: false)
      end

      after(:each) do
        Cartodb::Central.stubs(:sync_data_with_cartodb_central?).returns(false)
        @oauth_app.destroy! if @oauth_app
        @oauth_app2.destroy! if @oauth_app2
      end

      after(:all) do
        @user_oauth.destroy!
      end

      describe '#create' do
        it 'creates app in clouds from Central' do
          Cartodb::Central.stubs(:sync_data_with_cartodb_central?).returns(true)
          params = { id: '26da639b-0b8c-4e81-aeb4-33b81fd0cacb',
                     name: 'name1',
                     redirect_uris: ['https://re.dir'],
                     icon_url: 'some.png',
                     client_id: '1234',
                     client_secret: '5678',
                     restricted: false }
          Cartodb::Central.any_instance
                          .stubs(:create_oauth_app)
                          .with(@user_oauth.username,
                                params)
                          .returns({})
                          .once

          @oauth_app2 = OauthApp.new(params.merge(user: @user_oauth))
          @oauth_app2.id = params[:id]
          @oauth_app2.save!
        end

        it 'creates app if Central is disabled' do
          Cartodb::Central.stubs(:sync_data_with_cartodb_central?).returns(false)
          Cartodb::Central.any_instance.stubs(:create_oauth_app).never

          @oauth_app2 = OauthApp.create!(user: @user_oauth,
                                         name: 'name1',
                                         redirect_uris: ['https://re.dir'],
                                         icon_url: 'some.png')
        end

        it 'creates app if Central is disabled and no user' do
          Cartodb::Central.stubs(:sync_data_with_cartodb_central?).returns(false)
          Cartodb::Central.any_instance.stubs(:create_oauth_app).never

          @oauth_app2 = OauthApp.create!(name: 'name1',
                                         redirect_uris: ['https://re.dir'],
                                         icon_url: 'some.png')
        end
      end

      describe '#update' do
        it 'updates app in clouds from Central' do
          Cartodb::Central.stubs(:sync_data_with_cartodb_central?).returns(true)
          Cartodb::Central.any_instance
                          .stubs(:update_oauth_app)
                          .with(@user_oauth.username, @oauth_app.id, name: 'updated')
                          .returns({})
                          .once

          @oauth_app.name = 'updated'
          @oauth_app.save!
        end

        it 'updates app if Central is disabled' do
          Cartodb::Central.stubs(:sync_data_with_cartodb_central?).returns(false)
          Cartodb::Central.any_instance.stubs(:update_oauth_app).never

          @oauth_app.name = 'updated'
          @oauth_app.save!
        end

        it 'updates app if Central is avoid_sync_central' do
          Cartodb::Central.stubs(:sync_data_with_cartodb_central?).returns(true)
          Cartodb::Central.any_instance.stubs(:update_oauth_app).never

          @oauth_app.avoid_sync_central = true
          @oauth_app.save!
        end

        it 'updates app to no user' do
          Cartodb::Central.stubs(:sync_data_with_cartodb_central?).returns(true)
          Cartodb::Central.any_instance.stubs(:update_oauth_app).never

          @oauth_app.user = nil
          @oauth_app.save!

          @oauth_app.reload.user.should be_nil
        end
      end

      describe '#destroy' do
        it 'deletes app in clouds from Central' do
          Cartodb::Central.stubs(:sync_data_with_cartodb_central?).returns(true)
          Cartodb::Central.any_instance
                          .stubs(:delete_oauth_app)
                          .with(@user_oauth.username, @oauth_app.id)
                          .returns({})
                          .once

          @oauth_app.destroy!
        end

        it 'deletes app if Central is disabled' do
          Cartodb::Central.stubs(:sync_data_with_cartodb_central?).returns(false)
          Cartodb::Central.any_instance.stubs(:delete_oauth_app).never

          @oauth_app.destroy!
        end
      end
    end

    it 'fills client id and secret automatically' do
      app = OauthApp.new
      app.save

      expect(app.client_id).to(be_present)
      expect(app.client_secret).to(be_present)
    end
  end
end
