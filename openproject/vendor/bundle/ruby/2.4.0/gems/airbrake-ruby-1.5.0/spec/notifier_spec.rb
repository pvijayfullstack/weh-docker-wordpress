# coding: utf-8
require 'spec_helper'

RSpec.describe Airbrake::Notifier do
  def expect_a_request_with_body(body)
    expect(a_request(:post, endpoint).with(body: body)).to have_been_made.once
  end

  let(:project_id) { 105138 }
  let(:project_key) { 'fd04e13d806a90f96614ad8e529b2822' }
  let(:localhost) { 'http://localhost:8080' }

  let(:endpoint) do
    "https://airbrake.io/api/v3/projects/#{project_id}/notices?key=#{project_key}"
  end

  let(:airbrake_params) do
    { project_id: project_id,
      project_key: project_key,
      logger: Logger.new(StringIO.new) }
  end

  let(:ex) { AirbrakeTestError.new }

  before do
    stub_request(:post, endpoint).to_return(status: 201, body: '{}')
    @airbrake = described_class.new(airbrake_params)
  end

  describe "#new" do
    context "raises error if" do
      example ":project_id is not provided" do
        expect { described_class.new(project_key: project_key) }.
          to raise_error(Airbrake::Error, ':project_id is required')
      end

      example ":project_key is not provided" do
        expect { described_class.new(project_id: project_id) }.
          to raise_error(Airbrake::Error, ':project_key is required')
      end

      example "neither :project_id nor :project_key are provided" do
        expect { described_class.new({}) }.
          to raise_error(Airbrake::Error, ':project_id is required')
      end
    end

    context "when the argument is Airbrake::Config" do
      it "uses it instead of the hash" do
        airbrake = described_class.new(
          Airbrake::Config.new(project_id: 123, project_key: '321')
        )
        config = airbrake.instance_variable_get(:@config)
        expect(config.project_id).to eq(123)
        expect(config.project_key).to eq('321')
      end
    end
  end

  describe "#notify_sync" do
    describe "first argument" do
      context "when it is a Notice" do
        it "sends the argument" do
          notice = @airbrake.build_notice(ex)
          @airbrake.notify_sync(notice)

          # rubocop:disable Metrics/LineLength
          expected_body = %r|
            {"errors":\[{"type":"AirbrakeTestError","message":"App\scrashed!","backtrace":\[
            {"file":"[\w/-]+/spec/spec_helper.rb","line":\d+,"function":"<top\s\(required\)>"},
            {"file":"[\w/\-\.]+/rubygems/core_ext/kernel_require\.rb","line":\d+,"function":"require"},
            {"file":"[\w/\-\.]+/rubygems/core_ext/kernel_require\.rb","line":\d+,"function":"require"}
          |x
          # rubocop:enable Metrics/LineLength

          expect(
            a_request(:post, endpoint).
            with(body: expected_body)
          ).to have_been_made.once
        end

        it "appends provided params to the notice" do
          notice = @airbrake.build_notice(ex)
          @airbrake.notify_sync(notice, bingo: 'bango')

          expect_a_request_with_body(/"params":{.*"bingo":"bango".*}/)
        end
      end
    end

    describe "request" do
      before do
        @airbrake.notify_sync(ex, bingo: ['bango'], bongo: 'bish')
      end

      it "is being made over HTTPS" do
        expect(
          a_request(:post, endpoint).
          with { |req| req.uri.port == 443 }
        ).to have_been_made.once
      end

      describe "headers" do
        def expect_a_request_with_headers(headers)
          expect(
            a_request(:post, endpoint).
            with(headers: headers)
          ).to have_been_made.once
        end

        it "POSTs JSON to Airbrake" do
          expect_a_request_with_headers('Content-Type' => 'application/json')
        end

        it "sets User-Agent" do
          ua = "airbrake-ruby/#{Airbrake::AIRBRAKE_RUBY_VERSION} Ruby/#{RUBY_VERSION}"
          expect_a_request_with_headers('User-Agent' => ua)
        end
      end

      describe "body" do
        it "features 'notifier'" do
          expect_a_request_with_body(/"notifier":{"name":"airbrake-ruby"/)
        end

        it "features 'context'" do
          expect_a_request_with_body(/"context":{.*"os":"[\.\w-]+"/)
        end

        it "features 'errors'" do
          expect_a_request_with_body(
            /"errors":\[{"type":"AirbrakeTestError","message":"App crash/
          )
        end

        it "features 'backtrace'" do
          expect_a_request_with_body(
            %r|"backtrace":\[{"file":"/home/.+/spec/spec_helper.rb"|
          )
        end

        it "features 'params'" do
          expect_a_request_with_body(
            /"params":{"bingo":\["bango"\],"bongo":"bish"}/
          )
        end
      end
    end

    describe "response body when it is" do
      before do
        @stdout = StringIO.new
        params = {
          logger: Logger.new(@stdout).tap { |l| l.level = Logger::DEBUG }
        }
        @airbrake = described_class.new(airbrake_params.merge(params))
      end

      shared_examples "HTTP codes" do |code, body, expected_output|
        it "logs error #{code}" do
          stub_request(:post, endpoint).to_return(status: code, body: body)

          expect(@stdout.string).to be_empty

          response = @airbrake.notify_sync(ex)

          expect(@stdout.string).to match(expected_output)
          expect(response).to be_a Hash

          if response['error']
            expect(response['error']).to satisfy do |error|
              error.is_a?(Exception) || error.is_a?(String)
            end
          end
        end
      end

      context "a hash with response and invalid status" do
        include_examples 'HTTP codes', 200,
                         '{"id":"1","url":"https://airbrake.io/locate/1"}',
                         %r{unexpected code \(200\). Body: .+url":"https://airbrake.+}
      end

      context "an empty page" do
        include_examples 'HTTP codes', 200, '',
                         /ERROR -- : .+ unexpected code \(200\). Body: \[EMPTY_BODY\]/
      end

      context "a valid body with code 201" do
        include_examples 'HTTP codes', 201,
                         '{"id":"1","url":"https://airbrake.io/locate/1"}',
                         %r|DEBUG -- : .+url"=>"https://airbrake.io/locate/1"}|
      end

      context "a non-parseable page" do
        include_examples 'HTTP codes', 400, 'bingo bango bongo',
                         /ERROR -- : .+unexpected token at 'bingo.+'\)\. Body: bingo.+/
      end

      context "error 400" do
        include_examples 'HTTP codes', 400, '{"error": "Invalid Content-Type header."}',
                         /ERROR -- : .+ Invalid Content-Type header\./
      end

      context "error 401" do
        include_examples 'HTTP codes', 401,
                         '{"error":"Project not found or access denied."}',
                         /ERROR -- : .+ Project not found or access denied./
      end

      context "the rate-limit message" do
        include_examples 'HTTP codes', 429, '{"error": "Project is rate limited."}',
                         /ERROR -- : .+ Project is rate limited.+/
      end

      context "the internal server error" do
        include_examples 'HTTP codes', 500, 'Internal Server Error',
                         /ERROR -- : .+ unexpected code \(500\). Body: Internal.+ Error/
      end

      context "too long it truncates it and" do
        include_examples 'HTTP codes', 123, '123 ' * 1000,
                         /ERROR -- : .+ unexpected code \(123\). Body: .+ 123 123 1\.\.\./
      end
    end

    describe "connection timeout" do
      it "logs the error when it occurs" do
        stub_request(:post, endpoint).to_timeout

        stderr = StringIO.new
        params = airbrake_params.merge(logger: Logger.new(stderr))
        airbrake = described_class.new(params)

        airbrake.notify_sync(ex)

        expect(stderr.string).
          to match(/ERROR -- : .+ HTTP error: execution expired/)
      end
    end

    describe "unicode payload" do
      context "with valid strings" do
        it "works correctly" do
          @airbrake.notify_sync(ex, unicode: "ü ö ä Ä Ü Ö ß привет €25.00 한글")

          expect(
            a_request(:post, endpoint).
            with(body: /"unicode":"ü ö ä Ä Ü Ö ß привет €25.00 한글"/)
          ).to have_been_made.once
        end
      end

      context "with invalid strings" do
        it "doesn't raise error when string has invalid encoding" do
          expect do
            @airbrake.notify_sync('bingo', bongo: "bango\xAE")
          end.not_to raise_error
        end

        it "doesn't raise error when string has valid encoding, but invalid characters" do
          # Shenanigans to get a bad ASCII-8BIT string. Direct conversion raises error.
          encoded = Base64.encode64("\xD3\xE6\xBC\x9D\xBA").encode!('ASCII-8BIT')
          bad_string = Base64.decode64(encoded)

          expect do
            @airbrake.notify_sync('bingo', bongo: bad_string)
          end.not_to raise_error
        end
      end
    end

    describe "a closed IO object" do
      context "outside of the Rails environment" do
        it "is not getting truncated" do
          @airbrake.notify_sync(ex, bingo: IO.new(0).tap(&:close))

          expect(
            a_request(:post, endpoint).with(body: /"bingo":"#<IO:0x.+>"/)
          ).to have_been_made.once
        end
      end

      context "inside the Rails environment" do
        ##
        # Instances of this class contain a closed IO object assigned to an instance
        # variable. Normally, the JSON gem, which we depend on can parse closed IO
        # objects. However, because ActiveSupport monkey-patches #to_json and calls
        # #to_a on them, they raise IOError when we try to serialize them.
        #
        # @see https://goo.gl/0A3xNC
        class ObjectWithIoIvars
          def initialize
            @bongo = Tempfile.new('bongo').tap(&:close)
          end

          # @raise [NotImplementedError] when inside a Rails environment
          def to_json(*)
            raise NotImplementedError
          end
        end

        ##
        # @see ObjectWithIoIvars
        class ObjectWithNestedIoIvars
          def initialize
            @bish = ObjectWithIoIvars.new
          end

          # @see ObjectWithIoIvars#to_json
          def to_json(*)
            raise NotImplementedError
          end
        end

        shared_examples 'truncation' do |params, expected|
          it "filters it out" do
            @airbrake.notify_sync(ex, params)

            expect(
              a_request(:post, endpoint).with(body: expected)
            ).to have_been_made.once
          end
        end

        context "which is an instance of" do
          context "Tempfile" do
            params = { bango: Tempfile.new('bongo').tap(&:close) }
            include_examples 'truncation', params, /"bango":"#<(Temp)?file:0x.+>"/i
          end

          context "a non-IO class but with" do
            context "IO ivars" do
              params = { bongo: ObjectWithIoIvars.new }
              include_examples 'truncation', params, /"bongo":".+ObjectWithIoIvars.+"/
            end

            context "a non-IO ivar, which contains an IO ivar itself" do
              params = { bish: ObjectWithNestedIoIvars.new }
              include_examples 'truncation', params, /"bish":".+ObjectWithNested.+"/
            end
          end
        end

        context "which is deeply nested inside a hash" do
          params = { bingo: { bango: { bongo: ObjectWithIoIvars.new } } }
          include_examples(
            'truncation',
            params,
            /"params":{"bingo":{"bango":{"bongo":".+ObjectWithIoIvars.+"}}}/
          )
        end

        context "which is deeply nested inside an array" do
          params = { bingo: [[ObjectWithIoIvars.new]] }
          include_examples(
            'truncation',
            params,
            /"params":{"bingo":\[\[".+ObjectWithIoIvars.+"\]\]}/
          )
        end
      end
    end
  end

  describe "#notify" do
    it "sends an exception asynchronously" do
      @airbrake.notify(ex, bingo: 'bango')

      sleep 1

      expect_a_request_with_body(/params":{"bingo":"bango"}/)
    end

    it "returns nil" do
      expect(@airbrake.notify(ex)).to be_nil
      sleep 1
    end

    it "falls back to synchronous delivery when the async sender is dead" do
      out = StringIO.new
      notifier = described_class.new(airbrake_params.merge(logger: Logger.new(out)))
      async_sender = notifier.instance_variable_get(:@async_sender)

      expect(async_sender).to have_workers
      async_sender.instance_variable_get(:@workers).list.each(&:kill)
      sleep 1
      expect(async_sender).not_to have_workers

      notifier.notify('bango')
      expect(out.string).to match(/falling back to sync delivery/)

      notifier.close
    end

    it "respawns workers on fork()", skip: %w(jruby rbx).include?(RUBY_ENGINE) do
      out = StringIO.new
      notifier = described_class.new(airbrake_params.merge(logger: Logger.new(out)))

      notifier.notify('bingo', bingo: 'bango')
      sleep 1
      expect(out.string).not_to match(/falling back to sync delivery/)
      expect_a_request_with_body(/"bingo":"bango"/)

      pid = fork do
        expect(notifier.instance_variable_get(:@async_sender)).to have_workers
        notifier.notify('bango', bongo: 'bish')
        sleep 1
        expect(out.string).not_to match(/falling back to sync delivery/)
        expect_a_request_with_body(/"bingo":"bango"/)
      end

      Process.wait(pid)
      notifier.close
      expect(notifier.instance_variable_get(:@async_sender)).not_to have_workers
    end
  end

  describe "#add_filter" do
    it "filters notices" do
      @airbrake.add_filter do |notice|
        if notice[:params][:password]
          notice[:params][:password] = '[Filtered]'.freeze
        end
      end

      @airbrake.notify_sync(ex, password: 's4kr4t')

      expect(
        a_request(:post, endpoint).
        with(body: /params":{"password":"\[Filtered\]"}/)
      ).to have_been_made.once
    end

    it "accepts multiple filters" do
      [:bingo, :bongo, :bash].each do |key|
        @airbrake.add_filter do |notice|
          notice[:params][key] = '[Filtered]'.freeze if notice[:params][key]
        end
      end

      @airbrake.notify_sync(ex, bingo: ['bango'], bongo: 'bish', bash: 'bosh')

      # rubocop:disable Metrics/LineLength
      body = /"params":{"bingo":"\[Filtered\]","bongo":"\[Filtered\]","bash":"\[Filtered\]"}/
      # rubocop:enable Metrics/LineLength

      expect(
        a_request(:post, endpoint).
        with(body: body)
      ).to have_been_made.once
    end

    it "ignores all notices" do
      @airbrake.add_filter(&:ignore!)

      @airbrake.notify_sync(ex)

      expect(a_request(:post, endpoint)).not_to have_been_made
    end

    it "ignores specific notices" do
      @airbrake.add_filter do |notice|
        notice.ignore! if notice[:errors][0][:type] == 'RuntimeError'
      end

      @airbrake.notify_sync(RuntimeError.new('Not caring!'))
      expect(a_request(:post, endpoint)).not_to have_been_made

      @airbrake.notify_sync(ex)
      expect(a_request(:post, endpoint)).to have_been_made.once
    end
  end

  describe "#blacklist_keys" do
    describe "the list of arguments" do
      it "accepts regexps" do
        @airbrake.blacklist_keys(/\Abin/)

        @airbrake.notify_sync(ex, bingo: 'bango')

        expect(
          a_request(:post, endpoint).
          with(body: /"params":{"bingo":"\[Filtered\]"}/)
        ).to have_been_made.once
      end

      it "accepts symbols" do
        @airbrake.blacklist_keys(:bingo)

        @airbrake.notify_sync(ex, bingo: 'bango')

        expect(
          a_request(:post, endpoint).
          with(body: /"params":{"bingo":"\[Filtered\]"}/)
        ).to have_been_made.once
      end

      it "accepts strings" do
        @airbrake.blacklist_keys('bingo')

        @airbrake.notify_sync(ex, bingo: 'bango', bbingoo: 'bbangoo')

        expect(
          a_request(:post, endpoint).
          with(body: /"params":{"bingo":"\[Filtered\]","bbingoo":"bbangoo"}/)
        ).to have_been_made.once
      end
    end

    describe "hash values" do
      context "non-recursive" do
        it "filters nested hashes" do
          @airbrake.blacklist_keys('bish')

          @airbrake.notify_sync(ex, bongo: { bish: 'bash' })

          expect(
            a_request(:post, endpoint).
            with(body: /"params":{"bongo":{"bish":"\[Filtered\]"}}/)
          ).to have_been_made.once
        end
      end

      context "recursive" do
        it "filters recursive hashes" do
          @airbrake.blacklist_keys('bango')

          bongo = { bingo: {} }
          bongo[:bingo][:bango] = bongo

          @airbrake.notify_sync(ex, bongo)

          expect(
            a_request(:post, endpoint).
            with(body: /"params":{"bingo":{"bango":"\[Filtered\]"}}/)
          ).to have_been_made.once
        end
      end
    end

    it "filters query parameters correctly" do
      @airbrake.blacklist_keys(%w(bish))

      notice = @airbrake.build_notice(ex)
      notice[:context][:url] = 'http://localhost:3000/crash?foo=bar&baz=bongo&bish=bash&color=%23FFAAFF'

      @airbrake.notify_sync(notice)

      # rubocop:disable Metrics/LineLength
      expected_body =
        %r("context":{.*"url":"http://localhost:3000/crash\?foo=bar&baz=bongo&bish=\[Filtered\]&color=%23FFAAFF".*})
      # rubocop:enable Metrics/LineLength

      expect(
        a_request(:post, endpoint).
        with(body: expected_body)
      ).to have_been_made.once
    end

    it "filters out user" do
      @airbrake.blacklist_keys('user')

      notice = @airbrake.build_notice(ex)
      notice[:context][:user] = { id: 1337, name: 'Bingo Bango' }

      @airbrake.notify_sync(notice)

      expect_a_request_with_body(/"user":"\[Filtered\]"/)
    end

    it "filters out individual user fields" do
      @airbrake.blacklist_keys('name')

      notice = @airbrake.build_notice(ex)
      notice[:context][:user] = { id: 1337, name: 'Bingo Bango' }

      @airbrake.notify_sync(notice)

      expect_a_request_with_body(/"user":{"id":1337,"name":"\[Filtered\]"}/)
    end
  end

  describe "#whitelist_keys" do
    describe "the list of arguments" do
      it "accepts regexes" do
        @airbrake.whitelist_keys(/\Abin/)

        @airbrake.notify_sync(ex, bingo: 'bango', bongo: 'bish', bash: 'bosh')

        body = /"params":{"bingo":"bango","bongo":"\[Filtered\]","bash":"\[Filtered\]"}/

        expect(
          a_request(:post, endpoint).
          with(body: body)
        ).to have_been_made.once
      end

      it "accepts symbols" do
        @airbrake.whitelist_keys(:bongo)

        @airbrake.notify_sync(ex, bingo: 'bango', bongo: 'bish', bash: 'bosh')

        body = /"params":{"bingo":"\[Filtered\]","bongo":"bish","bash":"\[Filtered\]"}/

        expect(
          a_request(:post, endpoint).
          with(body: body)
        ).to have_been_made.once
      end

      it "accepts strings" do
        @airbrake.whitelist_keys('bash')

        @airbrake.notify_sync(
          ex,
          bingo: 'bango',
          bongo: 'bish',
          bash: 'bosh',
          bbashh: 'bboshh'
        )

        expect(
          a_request(:post, endpoint).
          with(
            body: /"params":{"bingo":"\[Filtered\]","bongo":"\[Filtered\]",
                   "bash":"bosh","bbashh":"\[Filtered\]"}/x
          )
        ).to have_been_made.once
      end
    end

    describe "hash values" do
      context "non-recursive" do
        it "filters out everything but the provided keys" do
          @airbrake.whitelist_keys(%w(bongo bish))

          @airbrake.notify_sync(ex, bingo: 'bango', bongo: { bish: 'bash' })

          expect(
            a_request(:post, endpoint).
            with(body: /"params":{"bingo":"\[Filtered\]","bongo":{"bish":"bash"}}/)
          ).to have_been_made.once
        end
      end

      context "recursive" do
        it "errors when nested hashes are not filtered" do
          @airbrake.whitelist_keys(%w(bingo bango))

          bongo = { bingo: {} }
          bongo[:bingo][:bango] = bongo

          if RUBY_ENGINE == 'jruby'
            # JRuby might raise two different exceptions, which represent the
            # same thing. One is a Java exception, the other is a Ruby
            # exception. It's probably a JRuby bug:
            # https://github.com/jruby/jruby/issues/1903
            begin
              expect do
                @airbrake.notify_sync(ex, bongo)
              end.to raise_error(SystemStackError)
            rescue RSpec::Expectations::ExpectationNotMetError
              expect do
                @airbrake.notify_sync(ex, bongo)
              end.to raise_error(java.lang.StackOverflowError)
            end
          else
            expect do
              @airbrake.notify_sync(ex, bongo)
            end.to raise_error(SystemStackError)
          end
        end
      end
    end

    describe "context/url" do
      it "filters query parameters correctly" do
        @airbrake.whitelist_keys(%w(bish))

        notice = @airbrake.build_notice(ex)
        notice[:context][:url] = 'http://localhost:3000/crash?foo=bar&baz=bongo&bish=bash'

        @airbrake.notify_sync(notice)

        # rubocop:disable Metrics/LineLength
        expected_body =
          %r("context":{.*"url":"http://localhost:3000/crash\?foo=\[Filtered\]&baz=\[Filtered\]&bish=bash".*})
        # rubocop:enable Metrics/LineLength

        expect(
          a_request(:post, endpoint).
          with(body: expected_body)
        ).to have_been_made.once
      end

      context "given a non-standard URL" do
        it "leaves the URL unfiltered" do
          @airbrake.whitelist_keys(%w(bish))

          notice = @airbrake.build_notice(ex)
          notice[:context][:url] =
            'http://localhost:3000/cra]]]sh?foo=bar&baz=bongo&bish=bash'

          @airbrake.notify_sync(notice)

          # rubocop:disable Metrics/LineLength
          expected_body =
            %r("context":{.*"url":"http://localhost:3000/cra\]\]\]sh\?foo=bar&baz=bongo&bish=bash".*})
          # rubocop:enable Metrics/LineLength

          expect(
            a_request(:post, endpoint).
            with(body: expected_body)
          ).to have_been_made.once
        end
      end

      context "given a URL without a query" do
        it "skips params filtering and leaves the URL untouched" do
          @airbrake.whitelist_keys(%w(bish))

          notice = @airbrake.build_notice(ex)
          notice[:context][:url] = 'http://localhost:3000/crash'

          @airbrake.notify_sync(notice)

          expect(
            a_request(:post, endpoint).
            with(body: %r("context":{.*"url":"http://localhost:3000/crash".*}))
          ).to have_been_made.once
        end
      end
    end
  end

  describe "#build_notice" do
    it "builds a notice from exception" do
      expect(@airbrake.build_notice(ex)).to be_an Airbrake::Notice
    end

    context "given a non-exception with calculated internal frames only" do
      it "returns the internal frames nevertheless" do
        backtrace = [
          "/airbrake-ruby/lib/airbrake-ruby/notifier.rb:84:in `build_notice'",
          "/airbrake-ruby/lib/airbrake-ruby/notifier.rb:124:in `send_notice'",
          "/airbrake-ruby/lib/airbrake-ruby/notifier.rb:52:in `notify_sync'"
        ]

        # rubocop:disable Metrics/LineLength
        parsed_backtrace = [
          { file: '/airbrake-ruby/lib/airbrake-ruby/notifier.rb', line: 84, function: 'build_notice' },
          { file: '/airbrake-ruby/lib/airbrake-ruby/notifier.rb', line: 124, function: 'send_notice' },
          { file: '/airbrake-ruby/lib/airbrake-ruby/notifier.rb', line: 52, function: 'notify_sync' }
        ]
        # rubocop:enable Metrics/LineLength

        allow(Kernel).to receive(:caller).and_return(backtrace)

        notice = @airbrake.build_notice('bingo')
        expect(notice[:errors][0][:backtrace]).to eq(parsed_backtrace)
      end
    end
  end

  describe "#close" do
    context "when using #notify on a closed notifier" do
      it "raises error" do
        notifier = described_class.new(airbrake_params)
        notifier.close

        expect { notifier.notify(AirbrakeTestError.new) }.
          to raise_error(Airbrake::Error, /closed Airbrake instance/)
      end
    end

    context "at program exit when it was closed manually" do
      it "doesn't raise error", skip: RUBY_ENGINE == 'jruby' do
        expect do
          Process.wait(fork { described_class.new(airbrake_params) })
        end.not_to raise_error
      end
    end
  end

  describe "#create_deploy" do
    let(:deploy_endpoint) do
      "https://airbrake.io/api/v4/projects/#{project_id}/deploys?key=#{project_key}"
    end

    it "sends a request to the deploy API" do
      stub_request(:post, deploy_endpoint).to_return(status: 201, body: '{"id":"123"}')
      @airbrake.create_deploy({})
      expect(a_request(:post, deploy_endpoint)).to have_been_made.once
    end
  end
end
