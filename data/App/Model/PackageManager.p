# Created by IntelliJ IDEA.
# User: ibodnar
# Date: 17.05.16
# Time: 19:31
# To change this template use File | Settings | File Templates.

@CLASS
PackageManager

@OPTIONS
locals


@auto[]
###


@create[githubApi]
    $self.githubApi[$githubApi]
###


@addVersion[package;sha;version][result]
    ^if(-f '/p/${package.targetDir}.json'){
        $fileData[^self.parseJson[/p/${package.targetDir}.json](true)]
    }{
        $fileData[
            $.packages[
                $.[$package.name][^hash::create[]]
            ]
        ]
    }

    ^if(
        !^fileData.packages.[$package.name].contains[$name] ||
        $fileData.packages.[$package.name].$version.source.reference ne $sha
    ){
        ^connect[$MAIN:SQL.connect-string]{
            ^void:sql{
                DELETE FROM version WHERE version.version = $version
            }
            $fileData.packages.[$package.name].$version[^self.createPackageConfig[$data;$package.name;$sha;$version]]
            $value[$fileData.packages.[$package.name].$version]

            ^void:sql{
                INSERT INTO version(package_id, version, name, type, description, class_path, source_url, source_type, source_reference, dist_url, dist_type, dist_reference, parsekit_json)
                VALUES ^self.generateInsertValues[$package;$fileData.packages.[$package.name];$version]
            }
        }
    }

    $string[^json:string[$fileData;$.indent(true)]]
    ^string.save[/p/${package.targetDir}.json]
###


@addVersions[package;refs][result]
    ^connect[$MAIN:SQL.connect-string]{
        ^void:sql{
            DELETE FROM version WHERE version.package_id = $package.id
        }
    }

    ^if(-f '/p/${package.targetDir}.json'){
        $oldFileData[^self.parseJson[/p/${package.targetDir}.json](true)]
    }

    $fileData[
        $.packages[
            $.[$package.name][^hash::create[]]
        ]
    ]

    ^refs.foreach[k;ref]{
        $version[^ref.ref.match[(refs\/(?:heads|tags)\/)][gi]{}]
        $sha[$ref.object.sha]
        ^if(
            ^fileData.packages.[$package.name].contains[$version] &&
            $fileData.packages.[$package.name].$version.source.reference eq $sha
        ){
#           if not changed ref then do not update
            $fileData.packages.[$package.name].$version[$oldFileData.packages.[$package.name].$version]
        }{
            $fileData.packages.[$package.name].$version[^self.createPackageConfig[$data;$package.name;$sha;$version]]
        }
    }

    $values[^self.generateInsertValues[$package;$fileData.packages.[$package.name]]]

    ^connect[$MAIN:SQL.connect-string]{
        ^void:sql{
        INSERT INTO version(package_id, version, name, type, description, class_path, source_url, source_type, source_reference, dist_url, dist_type, dist_reference, parsekit_json)
        VALUES $values
        }
    }

    $string[^json:string[$fileData;$.indent(true)]]
    ^string.save[/p/${package.targetDir}.json]
###


@removeVersion[package;version][result]
    ^connect[$MAIN:SQL.connect-string]{
        ^void:sql{
            DELETE FROM version WHERE version.package_id = $package.id AND version.version = '$version'
        }
    }

    ^if(-f '/p/${package.targetDir}.json'){
        $fileData[^self.parseJson[/p/${package.targetDir}.json](true)]

        ^fileData.packages.[$package.name].delete[$version]

        $string[^json:string[$fileData;$.indent(true)]]
        ^string.save[/p/${package.targetDir}.json]
    }
###


@createPackageConfig[data;packageName;sha;version][result]
    $parsekitConfig[^self.githubApi.getParsekitFile[$packageName;$sha]]
    $parsekitConfig.name[$packageName]
    $parsekitConfig.targetDir[$packageName]
    $parsekitConfig.uid(1)
    $parsekitConfig.version[^if($version eq master]){dev-master}{$version}]
    $parsekitConfig.source[
        $.type[git]
        $.url[$data.repository.clone_url]
        $.reference[$sha]
    ]
    $parsekitConfig.dist[
        $.type[zip]
        $.url[https://api.github.com/repos/$packageName/zipball/$sha]
        $.reference[$sha]
    ]

    $result[$parsekitConfig]
###


@parseJson[url;local][result]
    $file[^self.load[$url]($local)]
    $result[^json:parse[^taint[as-is][$file.text]]]
###


@load[url;local][result]
    ^if(def $local && $local){
        $result[^file::load[text;$url]]
    }{
        $result[^curl:load[
            $.url[^taint[as-is][$url]]
            $.useragent[parsekit]
            $.timeout(20)
            $.ssl_verifypeer(0)
        ]]
    }
###


@generateInsertValues[package;packages;version][result]
    $result[^packages.foreach[packageVersion;value]{
        ^if(def $version && $packageVesion eq $version){
            ('$package.id', '$value.version', '$package.name', '$value.type', '$value.description', '$value.class_path', '$value.source.url', '$value.source.type', '$value.source.reference', '$value.dist.url', '$value.dist.type', '$value.dist.reference', '^json:string[^self.githubApi.getParsekitFile[$package.name;$sha]]]')
        }
    }[,]]
###