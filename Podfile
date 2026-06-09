use_frameworks!

#inhibit_all_warnings!

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      deployment_target = config.build_settings['MACOSX_DEPLOYMENT_TARGET']
      if deployment_target.nil? || Gem::Version.new(deployment_target) < Gem::Version.new('11.5')
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '11.5'
      end
      if ['RxSwift', 'RxRelay'].include?(target.name)
        config.build_settings['SWIFT_SUPPRESS_WARNINGS'] = 'YES'
      end
    end
  end
  stubs_path = File.join(installer.sandbox.root, '..', '..', 'LookinOsAppMCP', 'Sources', 'stubs')
  Dir.glob(File.join(installer.sandbox.root, 'Target Support Files', 'LookinShared', '*.xcconfig')).each do |path|
    content = File.read(path)
    unless content.include?('LookinOsAppMCP/Sources/stubs')
      content += "\nHEADER_SEARCH_PATHS = $(inherited) #{stubs_path}\n"
      File.write(path, content)
    end
  end
end

target 'LookinClient' do 
    platform :osx, '11.5'
    pod 'AppCenter'
    pod 'RxSwift', '~> 6.8'
    pod 'RxRelay', '~> 6.8'
    pod 'Sparkle', '~> 1.0'
    pod 'LookinShared', :path => '../LookinServer/'
    pod 'LookinOsAppMCP', :path => '../LookinOsAppMCP/'
    #pod 'LookinShared', :git => 'https://github.com/AlexNikov/LookinServer.git', :branch => 'develop'
end

target 'LookinClientUITests' do
    platform :osx, '11.5'
    inherit! :search_paths
end
