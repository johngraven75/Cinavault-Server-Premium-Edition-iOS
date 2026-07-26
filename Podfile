platform :ios, '17.0'
use_frameworks! :linkage => :static

install! 'cocoapods', :deterministic_uuids => true

target 'CinaVaultIOS' do
  pod 'google-cast-sdk', '~> 4.8.4'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |configuration|
      configuration.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end

  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.user_project.native_targets.each do |target|
      target.build_configurations.each do |configuration|
        configuration.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      end
    end
    aggregate_target.user_project.save
  end
end
