from conan import ConanFile
from conan.tools.cmake import CMakeDeps, CMakeToolchain


class FlutterMidiProFluidSynthDepsProbe(ConanFile):
    settings = "os", "arch", "compiler", "build_type"

    def requirements(self):
        self.requires("libsndfile/1.2.2")

    def configure(self):
        self.options["libsndfile"].shared = False
        self.options["libsndfile"].with_external_libs = True
        self.options["libsndfile"].with_mpeg = False

    def generate(self):
        CMakeDeps(self).generate()
        CMakeToolchain(self).generate()
