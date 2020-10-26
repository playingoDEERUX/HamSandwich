-- premake5.lua
dofile "tools/build/gmake2_deps.lua"
dofile "tools/build/android_studio.lua"
dofile "tools/build/emscripten.lua"

workspace "HamSandwich"
	location "build"
	configurations { "debug", "release", "debug64", "release64" }

	filter { "action:android-studio" }
		location "build/android"
		android_abis { "armeabi-v7a" }

function base_project(name)
	project(name)
		kind "WindowedApp"
		language "C++"
		cppdialect "C++17"
		architecture "x86"
		targetdir("build/%{cfg.toolset}-%{cfg.buildcfg}/%{prj.name}/")
		objdir("build/%{cfg.toolset}-%{cfg.buildcfg}/%{prj.name}/obj/")

		defines { 'PROJECT_NAME="%{prj.name}"' }

		files {
			"source/" .. name .. "/**.h",
			"source/" .. name .. "/**.cpp",
			"source/" .. name .. "/**.c",
		}

		filter "configurations:*64"
			architecture "x86_64"

		filter "configurations:debug*"
			kind "ConsoleApp"
			defines { "_DEBUG" }
			symbols "On"

		filter "configurations:release*"
			defines { "NDEBUG" }
			optimize "On"

		filter { "toolset:gcc", "system:Windows" }
			linkoptions { "-static-libgcc", "-static-libstdc++" }

		filter "action:vs*"
			-- At least some versions of VS2017 don't recognize "C++17".
			cppdialect "C++latest"
			defines { "_CRT_SECURE_NO_WARNINGS", "NOMINMAX", "SDL_UNPREFIXED" }
			-- The MSVC dependency script puts the SDL2 binaries here.
			includedirs {
				"build/SDL2-msvc/include",
				"build/SDL2_mixer-msvc/include",
				"build/SDL2_image-msvc/include",
			}
			libdirs {
				"build/SDL2-msvc/lib/x86",
				"build/SDL2_mixer-msvc/lib/x86",
				"build/SDL2_image-msvc/lib/x86",
			}
			-- These emulate the `./run` script when running within VS.
			debugargs { "window" }
			debugenvs { "PATH=$(ProjectDir)/lib/x86/;%PATH%" }
			debugdir "$(ProjectDir)/game/%{prj.name}"

		filter "action:android-studio"
			defines { "SDL_UNPREFIXED" }
			buildoptions { "-fsigned-char", "-fexceptions" }

		filter { "toolset:emcc", "configurations:debug*" }
			linkoptions { "--emrun" }

		filter { "toolset:emcc" }
			linkoptions {
				"-s ALLOW_MEMORY_GROWTH=1",
				"--use-preload-cache",
				"-s ENVIRONMENT=web",
				"-s FORCE_FILESYSTEM=1",
				"-s EXTRA_EXPORTED_RUNTIME_METHODS=['ENV']"
			}

			-- coroutine support
			defines { "USE_COROUTINES" }
			buildoptions { "-fcoroutines-ts", "-Werror=unused-result" }

		filter {}
end

function library(name)
	base_project(name)
		kind "StaticLib"
end

function sdl2_project(name)
	base_project(name)
		-- Android application metadata.
		android_package "com.platymuus.hamsandwich.%{prj.name}"
		android_assetdirs {
			"build/assets/%{prj.name}/",
			"assets/android/",
		}

		-- Emscripten metadata.
		emscripten.html "assets/emscripten/*"

		-- Link SDL2 in the correct sequence.
		filter { "system:Windows", "not action:vs*" }
			links "mingw32"
		filter "system:Windows"
			links { "ws2_32", "winmm" }
		filter {}

		links { "SDL2main", "SDL2", "SDL2_mixer", "SDL2_image" }
end

function excludefiles(files)
	list = {}
	for i = 1, #files do
		list[i] = "source/%{prj.name}/" .. files[i]
	end
	removefiles(list)
end

function icon_file(icon)
	-- Workaround for bug in premake5's gmake2 generator, which does
	-- not count .res (object) files as resources, only .rc (source)
	filter { "system:Windows", "toolset:not clang" }
		files { "source/%{prj.name}/" .. icon .. ".rc" }

	filter { "system:Windows", "action:gmake2", "toolset:not clang" }
		linkoptions { "%{cfg.objdir}/" .. icon .. ".res" }

	-- Support for embedding the icon in the file on non-Windows systems
	filter { "system:not Windows" }
		files { "source/%{prj.name}/" .. icon .. ".rc" }
		makesettings("OBJECTS += $(OBJDIR)/" .. icon .. ".rc.o")

	filter { "system:not Windows", "files:**.rc" }
		buildmessage "%{file.name}"
		buildcommands { 'python3 ../tools/build/rescomp.py "%{file.path}" "%{cfg.objdir}/%{file.basename}.rc.cpp"' }
		buildoutputs { "%{cfg.objdir}/" .. icon .. ".rc.cpp" }
		buildinputs { "tools/build/rescomp.py" }

	-- Convert the icon to a resource
	filter { "action:android-studio" }
		android_icon("source/%{prj.name}/" .. icon .. ".ico")

	filter {}
end

function pch(name)
	--filter "action:vs*"
	--	pchheader(name .. ".h")
	--	pchsource("source/%{prj.name}/" .. name .. ".cpp")
	filter "action:not vs*"
		pchheader("source/%{prj.name}/" .. name .. ".h")
	filter {}
end

function depends(name)
	includedirs { "source/" .. name }
	links(name)
end

library "libextract"
	filter "toolset:gcc"
		buildoptions { "-Wall", "-Wextra" }

library "ham"
	depends "libextract"
	local function links_ham()
		depends "ham"
		links "libextract"
	end

	filter "toolset:gcc"
		buildoptions { "-Wall", "-Wextra" }

	filter "toolset:emcc"
		links { "SDL2", "SDL2_mixer", "SDL2_image" }

sdl2_project "lunatic"
	android_appname "Dr. Lunatic"
	icon_file "lunatic"
	links_ham()
	pch "winpch"
	defines { "EXPANDO" }

	installers {
		["lunatic_install.exe"] = {
			kind = "nsis",
			sha256sum = "b8013176ea8050db20a2b170a5273d5287ccde4b4923affb7c610bda89326c84",
			link = "https://hamumu.itch.io/dr-lunatic",
		}
	}

	filter "toolset:gcc"
		buildoptions { "-Wall", "-Wextra", "-Wno-unused-parameter" }

sdl2_project "supreme"
	android_appname "Supreme With Cheese"
	icon_file "lunatic"
	links_ham()
	pch "winpch"

	excludefiles {
		"monsterlist.cpp",
		"monsterai1.cpp",
		"monsterai2.cpp",
		"monsterai3.cpp",
		"monsterai4.cpp",
		"textitems.cpp",
		"textrooms.cpp",
	}

	installers {
		["supreme8_install.exe"] = {
			kind = "nsis",
			sha256sum = "1c105ad826be1e0697b5de8483c71ff943d04bce91fe3547b6f355e9bc1c42d4",
			link = "https://hamumu.itch.io/dr-lunatic-supreme-with-cheese",
		}
	}

	filter "toolset:gcc"
		buildoptions {
			"-Wall",
			"-Wno-unused-variable",
			"-Wno-unused-but-set-variable",
		}

sdl2_project "sleepless"
	android_appname "Sleepless Hollow"
	icon_file "lunatic"
	links_ham()
	pch "winpch"

	excludefiles {
		"monsterlist.cpp",
		"monsterai1.cpp",
		"monsterai2.cpp",
		"monsterai3.cpp",
		"monsterai4.cpp",
		"monsterhollow.cpp",
	}

	installers {
		["hollow_betainstall.exe"] = {
			kind = "nsis",
			sha256sum = "41660802318356fba53a21b4d368e191b3197030fb9e8eb833788f45c01c6f99",
			link = "https://hamumu.itch.io/sleepless-hollow",
		}
	}

	filter "toolset:gcc"
		buildoptions {
			"-Wall",
			"-Wno-unused-variable",
			"-Wno-unused-but-set-variable",
		}

sdl2_project "loonyland"
	android_appname "Loonyland: Halloween Hill"
	icon_file "loonyland"
	links_ham()
	pch "winpch"

	installers {
		["loonyland_install.EXE"] = {
			kind = "inno",
			sha256sum = "cf3cdc555297e41f6c2da61d89815dbbc740d6fc677c83ec6c6e1acfa117de34",
			link = "https://hamumu.itch.io/loonyland-halloween-hill",
		},
		["loonyland_editor.exe"] = {
			kind = "nsis",
			sha256sum = "865550d077e984ca28324aaf4291211aa4009cdad9f2b74144179c6342f2be39",
			link = "https://hamumu.itch.io/loonyland-halloween-hill",
		}
	}

sdl2_project "loonyland2"
	android_appname "Loonyland 2: Winter Woods"
	icon_file "loonyland2"
	links_ham()
	pch "winpch"
	defines { "DIRECTORS" }
	excludefiles {
		"monster_ai.cpp",
	}

	installers {
		["LL2CEinstall.exe"] = {
			kind = "nsis",
			sha256sum = "0806e1615eb94332bf805128d2d3857af420e93ee6f48692eebf17c05e9b14e2",
			link = "https://hamumu.itch.io/loonyland-2-winter-woods",
		}
	}

sdl2_project "mystic"
	android_appname "Kid Mystic"
	icon_file "mystic"
	links_ham()
	pch "winpch"

	installers {
		["mystic_install.exe"] = {
			kind = "inno",
			sha256sum = "c2d618176d23b974c01c00690b6afb0aaebd4c863dfff0bf8b1f66db1bdc2f65",
			link = "https://hamumu.itch.io/kid-mystic",
		}
	}
