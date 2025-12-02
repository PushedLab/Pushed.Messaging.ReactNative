const path = require('path');

module.exports = {
  project: {
    ios: {
      automaticPodsInstallation: true,
    },
  },
  dependencies: {
    '@PushedLab/pushed-react-native': {
      platforms: {
        ios: {
          podspecPath: path.join(
            __dirname,
            'node_modules',
            '@PushedLab',
            'pushed-react-native',
            'pushed-react-native.podspec'
          ),
        },
      },
    },
  },
};
