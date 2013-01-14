#!/bin/sh
#
# Script to as politely as possible, disable java in the browser on
# machines.
#
# See http://web.nvd.nist.gov/view/vuln/detail?vulnId=CVE-2013-0422
#
# Works with the 'Internet Plug-Ins' dir, that is used by Safari/Firefox.
#
# Chrome uses 32bit, Apple supplied Java, which, thankfully, is a pain to
# activate... But still check for it.
#

# Oracle's java package name.
jpkg='com.oracle.jre'

# Current latest version as per http://www.java.com/en/download/
fewer_bad_version='1.7.0_11'

# Where.. ooh, on 10.8 anyway, plugins go.
plugin_path='/Library/Internet Plug-Ins/'

set -e  # Bail on non-zero.
set -u  # Fail on unset variable access.

PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

remove_java_plugin() {

  magic_java_path=$1

  # let's rely on global variables, and hope -e mode saves us.
  if [ -d "${magic_java_path}" ]
  then

    # Make that disabled dir, if it's not already there. If it fails to
    # mkdir, then there's problems.
    if ! [ -d "${plugin_path}" ]
    then
      # strange edge case of no plugin dir, or it being somewhere weird.
      echo "Can't find the plugin dir of ${plugin_path} so bailing."
      exit 20
    fi

    [ -d "${plugin_path}/disabled" ] || mkdir "${plugin_path}/disabled"

    # I am not sure how much this helps, buuut, in case they've done this
    # before, I am making the name somewhat less liable to collide.
    now=$( date "+%Y%m%d%H%M" )
    disabled_dir=$( mktemp -d "${plugin_path}/disabled/JavaAppletPlugin_${now}_XXXXXXXXXX" || \
      { echo "Failed to make temp dir in ${plugin_path}. Problem" ; exit 30; } )

    # if we're here, we have a directory we can probably move it to.
    if mv "${magic_java_path}" "${disabled_dir}/"
    then
      echo "Moved java to '${disabled_dir}', should be disabled."
    else
      echo "Failed to move javaplugin to '${disabled_dir}'. Still there."
      exit 40
    fi
  fi

}

# Not used, as it involves trying to be too smart. Which has more scope
# for failing.
disable_plugin_in_safari() {

  local guess_the_common_user=$( last -100 | cut -f 1 -d ' ' | \
    egrep -v "^(nobody|Guest|daemon|shutdown|reboot|root)$" | \
    sort | uniq | head -1 )

  su ${guess_the_common_user} -c '\
      defaults write com.apple.Safari WebKitJavaEnabled -bool FALSE && \
      defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled -bool FALSE'

}

am_i_root() {
  return $( [ $( id -u ) -eq 0 ] )
}

main() {

  if ! am_i_root
  then
    echo "You need to be root to run this."
    exit 5
  fi

  if pkgutil --pkg-info "${jpkg}" >/dev/null 2>&1
  then
    # We have Oracle java... Which will override the apple one.

    # Yeah, check it!
    sketchy_magic_java_path="$(pkgutil --pkg-info "${jpkg}" | egrep "^(volume|location): " | cut -f 2- -d " " | tr -d "\n" )"

    if [ -d "${sketchy_magic_java_path}" ]
    then
      # we have it.

      java_bin="${sketchy_magic_java_path}/Contents/Home/bin/java"
      if [ -x "${java_bin}" ]
      then
        # yeah, we have a java too.
        java_version_string=$( "${java_bin}" -version 2>&1 | head -1 )
        java_version=$( echo "${java_version_string}" | cut -f 2 -d '"' )

        echo "Java plugin version is: ${java_version}"

        if [ "${java_version}" != "${fewer_bad_version}" ]
        then
          # upgrade code goes here.
          echo "If we were to upgrade it. That would go here. Instead, we're disabling it."

          # Nah, just remove it.
          remove_java_plugin "${sketchy_magic_java_path}"
        else
          echo "Already at version ${fewer_bad_version}, nothing to do."
          exit 0
        fi
      fi

    else
      echo "Java says it's installed, but can't find it at '${sketchy_magic_java_path}', problem?"
      echo "Maybe you've run this before? And tidied it up to the disabled dir?"
    fi
  else
    echo "Can't find ${jpkg} on here. So you don't have Oracle java in Safari/Firefox. That's good."
  fi

  # Do this too, as we don't know what browser they actually use all the
  # time, and if they swap back, we'd like to be protected (read, not
  # using Java) off the bat.
  check_system_java

  # If we make it this far, it might have worked!
  exit 0
}


# test for http://support.apple.com/kb/HT5559 style symlink to Java 6.
check_system_java() {

  hardcoded_plugin_name='/Library/Internet Plug-Ins/JavaAppletPlugin.plugin'
  hardcoded_real_plugin_path='/System/Library/Java/Support/Deploy.bundle/Contents/Resources/JavaPlugin2_NPAPI.plugin'

  if check_system_java_exists
  then
    echo "We have a plugin though."
    java_version_string=$( /usr/bin/java -version 2>&1 | head -1 )
    java_version=$( echo "${java_version_string}" | cut -f 2 -d '"' )

    echo "System I-hate-Oracle Java plugin version is probably around: ${java_version}"

    if [ -L "${hardcoded_plugin_name}" ]
    then
      if [ $( readlink "${hardcoded_plugin_name}" ) == "${hardcoded_real_plugin_path}" ]
      then
        echo "It's just the standard symlink. Am gonna delete it."
        rm -f "${hardcoded_plugin_name}"
        exit 0
      else
        # Case where it's not the same symlink, just move it out.
        remove_java_plugin "${hardcoded_plugin_name}"
      fi
    else
      # Case where it's not a symlink, just move it out.
      remove_java_plugin "${hardcoded_plugin_name}"
    fi

  else
    echo "No sign of plugin... Chrome-wise."
    exit 0
  fi
}

check_system_java_exists() {

  # We may have a system, or manually installed Java here too!
  if [ -d "/Library/Internet Plug-Ins/JavaAppletPlugin.plugin" ]
  then
    return 0
  fi

  return 1
}

# I miss C.
main
