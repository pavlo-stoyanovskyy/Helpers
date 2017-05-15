using System.IO;

namespace CopyFilesIntoOneFolder
{
    class Program
    {
        static void Main(string[] args)
        {
            const string sourcePath =
                @"C:\develop";

            const string distPath =
                @"C:\develop_no_structure";

            string[] directories = 
                Directory.GetFileSystemEntries(sourcePath, "*", SearchOption.AllDirectories);

            foreach (var currentDirectory in directories)
            {
                if (currentDirectory.Contains(".gitattributes") || currentDirectory.Contains(".gitignore") || currentDirectory.Contains(".tgitconfig"))
                    continue;

                FileAttributes attr = File.GetAttributes(currentDirectory);

                if ((attr & FileAttributes.Directory) == FileAttributes.Directory)
                {
                    var files =
                        Directory.GetFiles(currentDirectory);

                    foreach (var f in files)
                    {
                        var fileName = 
                            Path.GetFileName(f);

                        var distFilePath = $"{distPath}\\{fileName}";
                        var sourceFilePath = $"{currentDirectory}\\{fileName}";

                        if (File.Exists(sourceFilePath))
                        {
                            if (!string.IsNullOrWhiteSpace(sourceFilePath))
                            {
                                var path = 
                                    Path.GetDirectoryName(sourceFilePath);

                                if (path != null)
                                {
                                    var uniqueFileName = path
                                            .Replace(sourcePath, string.Empty)
                                            .Replace("\\", string.Empty);

                                    distFilePath = $"{distPath}\\{uniqueFileName}_{fileName}";
                                }
                            }
                        }

                        File.Copy(sourceFilePath, distFilePath);
                    }
                }
            }
        }

        //private static string CalculateMd5Hash(string input)
        //{
        //    MD5 md5 = MD5.Create();

        //    byte[] hash = md5.ComputeHash(Encoding.ASCII.GetBytes(input));

        //    StringBuilder sb = new StringBuilder();

        //    foreach (byte h in hash)
        //    {
        //        sb.Append(h.ToString("X2"));
        //    }

        //    return sb.ToString();
        //}
    }
}
