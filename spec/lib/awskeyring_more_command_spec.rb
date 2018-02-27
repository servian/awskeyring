require 'spec_helper'
require 'thor'
require_relative '../../lib/awskeyring_command'

describe AwskeyringCommand do
  context 'When we try to access AWS with a token' do
    let(:session_key) do
      double(
        attributes: { label: 'session-key test', account: 'ASIATESTTEST' },
        password: 'bigerlongbase64'
      )
    end
    let(:session_token) do
      double(
        attributes: { label: 'session-token test', account: 0 },
        password: 'evenlongerbase64token'
      )
    end

    before do
      allow(Awskeyring).to receive(:delete_expired).with(session_key, session_token)
                                                   .and_return([session_key, session_token])
      allow(Process).to receive(:spawn).exactly(1).with(/open "https:/).and_return(9999)
      allow(Process).to receive(:wait).exactly(1).with(9999)
    end

    it 'opens the AWS Console' do
      expect(Awskeyring).to receive(:get_pair).with('test').and_return(
        [session_key, session_token]
      )

      expect(Awskeyring).to_not receive(:get_item)
      expect { AwskeyringCommand.start(%w[console test]) }
        .to output("# Using temporary session credentials\n").to_stdout
    end
  end

  context 'When we try to access AWS without a token' do
    let(:item) do
      double(
        attributes: { label: 'account test', account: 'AKIATESTTEST' },
        password: 'biglongbase64'
      )
    end

    before do
      allow(Awskeyring).to receive(:get_pair).with('test').and_return(nil, nil)
      allow(Awskeyring).to receive(:get_item).with('test').and_return(item)
      allow_any_instance_of(Aws::STS::Client).to receive(:get_federation_token)
        .and_return(
          double(
            credentials: {
              access_key_id: 'ASIATESTETSTTETS',
              secret_access_key: 'verybiglonghexkey',
              session_token: 'evenlongerbiglonghexkey',
              expiration: 5
            }
          )
        )
      allow(Process).to receive(:spawn).exactly(1).with(/open "https:/).and_return(9999)
      allow(Process).to receive(:wait).exactly(1).with(9999)
    end

    it 'opens the AWS Console' do
      expect(Awskeyring).to receive(:get_item).with('test').and_return(item)
      expect(Process).to receive(:spawn).with(/open "https:.*console.aws.amazon.com%2Ftest%2Fhome"/)
      AwskeyringCommand.start(%w[console test -p test])
    end
  end

  context 'When we try to add an AWS account' do
    let(:access_key) { 'AKIA0123456789ABCDEF' }
    let(:secret_access_key) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FEQW3IUJV' }
    let(:mfa_arn) { 'arn:aws:iam::012345678901:mfa/readonly' }
    let(:bad_access_key) { 'akIA01_678F' }
    let(:bad_secret_access_key) { 'Password123' }
    let(:bad_mfa_arn) { 'arn:azure:iamnot::ABCD45678901:Administrators' }

    before do
      allow(Awskeyring).to receive(:add_item).and_return(nil)
      allow_any_instance_of(HighLine).to receive(:ask) { 'joe' }
    end

    it 'tries to add a valid account' do
      expect do
        AwskeyringCommand.start(['add', 'test', '-k', access_key, '-s', secret_access_key, '-m', mfa_arn])
      end.to output("# Added account test\n").to_stdout
    end

    it 'tries to add an invalid access_key' do
      expect do
        AwskeyringCommand.start(['add', 'test', '-k', bad_access_key, '-s', secret_access_key, '-m', mfa_arn])
      end.to raise_error(SystemExit).and output(/Invalid Access Key/).to_stderr
    end

    it 'tries to add an invalid secret' do
      expect do
        AwskeyringCommand.start(['add', 'test', '-k', access_key, '-s', bad_secret_access_key, '-m', mfa_arn])
      end.to raise_error(SystemExit).and output(/Secret Access Key is not 40 chars/).to_stderr
    end

    it 'tries to add an invalid mfa' do
      expect do
        AwskeyringCommand.start(['add', 'test', '-k', access_key, '-s', secret_access_key, '-m', bad_mfa_arn])
      end.to raise_error(SystemExit).and output(/Invalid MFA ARN/).to_stderr
    end
  end

  context 'When we try to add a Role' do
    let(:role_arn) { 'arn:aws:iam::012345678901:role/readonly' }
    let(:bad_role_arn) { 'arn:azure:iamnot::ABCD45678901:Administrators' }

    before do
      allow(Awskeyring).to receive(:add_role).and_return(nil)
      allow_any_instance_of(HighLine).to receive(:ask) { 'joe' }
    end

    it 'tries to add a valid role' do
      expect do
        AwskeyringCommand.start(['add-role', 'readonly', '-a', role_arn])
      end.to output(/# Added role readonly/).to_stdout
    end

    it 'tries to add an invalid role arn' do
      expect do
        AwskeyringCommand.start(['add-role', 'readonly', '-a', bad_role_arn])
      end.to raise_error(SystemExit).and output(/Invalid Role ARN/).to_stderr
    end
  end

  context 'when we try to rotate keys' do
    let(:old_item) do
      double(
        attributes: { label: 'account test', account: 'AKIATESTTEST' },
        password: 'biglongbase64'
      )
    end

    before do
      allow(Awskeyring).to receive(:get_pair).with('test').and_return(nil, nil)
      allow(Awskeyring).to receive(:get_item).with('test').and_return(old_item)
      allow(Awskeyring).to receive(:update_item).and_return(true)

      allow_any_instance_of(Keychain::Item).to receive(:save).and_return(true)

      allow_any_instance_of(Aws::IAM::Client).to receive(:list_access_keys).and_return(
        access_key_metadata: [
          {
            access_key_id: 'AKIATESTTEST',
            create_date: Time.parse('2016-12-01T22:19:58Z'),
            status: 'Active',
            user_name: 'Alice'
          }
        ]
      )
      allow_any_instance_of(Aws::IAM::Client).to receive(:create_access_key).and_return(
        access_key: {
          access_key_id: 'AKIAIOSFODNN7EXAMPLE',
          create_date: Time.parse('2015-03-09T18:39:23.411Z'),
          secret_access_key: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
          status: 'Active',
          user_name: 'Bob'
        }
      )
      allow_any_instance_of(Aws::IAM::Client).to receive(:delete_access_key).and_return({})
    end

    it 'calls the rotate method' do
      expect(Awskeyring).to receive(:get_item).with('test').and_return(old_item)
      expect(Awskeyring).to receive(:update_item).with(
        account: 'test',
        key: 'AKIAIOSFODNN7EXAMPLE',
        secret: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY'
      )

      expect do
        AwskeyringCommand.start(%w[rotate test])
      end.to output(/# Updated account test/).to_stdout
    end
  end

  context 'when we try to rotate too many keys' do
    let(:old_item) do
      double(
        attributes: { label: 'account test', account: 'AKIATESTTEST' },
        password: 'biglongbase64'
      )
    end

    before do
      allow(Awskeyring).to receive(:get_pair).with('test').and_return(nil, nil)
      allow(Awskeyring).to receive(:get_item).with('test').and_return(old_item)
      allow(Awskeyring).to receive(:update_item).and_return(true)

      allow_any_instance_of(Keychain::Item).to receive(:save).and_return(true)

      allow_any_instance_of(Aws::IAM::Client).to receive(:list_access_keys).and_return(
        access_key_metadata: [
          {
            access_key_id: 'AKIATESTTEST',
            create_date: Time.parse('2016-12-01T22:19:58Z'),
            status: 'Active',
            user_name: 'Alice'
          },
          {
            access_key_id: 'AKIA222222222EXAMPLE',
            create_date: Time.parse('2016-12-01T22:20:01Z'),
            status: 'Active',
            user_name: 'Alice'
          }
        ]
      )
    end

    it 'calls the rotate method and fails' do
      expect(Awskeyring).to receive(:get_item).with('test').and_return(old_item)
      expect(Awskeyring).to_not receive(:update_item)

      expect_any_instance_of(Aws::IAM::Client).to_not receive(:create_access_key)
      expect_any_instance_of(Aws::IAM::Client).to_not receive(:delete_access_key)

      expect do
        AwskeyringCommand.start(%w[rotate test])
      end.to raise_error(SystemExit).and output(/You have two access keys for account test/).to_stderr
    end
  end
end
