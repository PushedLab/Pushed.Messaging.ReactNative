const path = require('path');

module.exports = {
  dependency: {
    platforms: {
      ios: {
        // Ensure only the core podspec is auto-linked for the app target
        podspecPath: path.join(__dirname, 'pushed-react-native.podspec'),
      },
    },
  },
};









