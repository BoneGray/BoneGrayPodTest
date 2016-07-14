

Pod::Spec.new do |s|


  s.name         = "BoneGrayPodTest"
  s.version      = "0.0.1"
  s.summary      = "all kinds of categories for iOS develop"

  s.description  = <<-DESC
                      this project provide all kinds of categories for iOS developer 
                   DESC

  s.homepage     = "https://github.com/BoneGray"

  s.license      = "MIT"
  s.license      = { :type => "MIT", :file => "LICENSE" }


  s.author             = { "sol" => "yangming@bb.to" }


  s.platform     = :ios

  s.source       = { :git => "https://github.com/BoneGray/BoneGrayPodTest.git", :tag => "0.0.1" }


  s.source_files  = "Classes", "BoneGrayPodTest/Classes/**/*.{h,m}"
  s.exclude_files = "Classes/Exclude"

  s.requires_arc = true


end
