Pod::Spec.new do |s|
    s.name = "OnDeallocateX"
    s.version = "1.0.0"
    s.summary = "Code to track iOS objects deallocation"
    s.homepage = "https://github.com/ladeiko/OnDeallocateX"
    s.license = { :type => "CUSTOM", :file => "LICENSE" }
    s.author = { "Siarhei Ladzeika" => "sergey.ladeiko@gmail.com" }
    s.platform = :ios, "9.0"
    s.source = { :git => "https://github.com/ladeiko/OnDeallocateX.git", :tag => "#{s.version}" }
    s.source_files = "Classes/**/*.{h,m}"
    #s.frameworks = ""
    s.requires_arc = true
end
