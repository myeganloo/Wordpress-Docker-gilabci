#!/bin/bash

# Wait for WordPress to be ready
until wp core is-installed --allow-root; do
  echo "Waiting for WordPress to be ready..."
  sleep 5
done

# Check if ACF is already installed
if ! wp plugin is-installed advanced-custom-fields --allow-root; then
  echo "Installing Advanced Custom Fields..."
  wp plugin install advanced-custom-fields --allow-root --activate
else
  echo "Advanced Custom Fields is already installed."
  wp plugin activate advanced-custom-fields --allow-root
fi