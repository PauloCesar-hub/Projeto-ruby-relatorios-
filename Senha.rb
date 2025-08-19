def gerar_senha(tamanho = 12, usar_numeros = true, usar_simbolos = true)
  letras = ('a'..'z').to_a + ('A'..'Z').to_a
  numeros = ('0'..'9').to_a
  simbolos = %w[! @ # $ % & * ?]

  caracteres = letras
  caracteres += numeros if usar_numeros
  caracteres += simbolos if usar_simbolos

  senha = ""
  tamanho.times { senha << caracteres.sample }
  senha
end

def salvar_senhas(senhas)
  File.open("senhas.txt", "a") do |arquivo|
    senhas.each_with_index do |senha, i|
      arquivo.puts "Senha #{Time.now.strftime("%d/%m/%Y %H:%M:%S")} - #{senha}"
    end
  end
end

def listar_senhas
  if File.exist?("senhas.txt")
    puts "\n📂 Senhas salvas em 'senhas.txt':\n\n"
    puts File.read("senhas.txt")
  else
    puts "\n⚠️ Nenhuma senha salva ainda!"
  end
end

# menu
loop do
  puts "\n============================"
  puts "🔐 GERADOR DE SENHAS RUBY"
  puts "1 - Gerar novas senhas"
  puts "2 - Listar senhas salvas"
  puts "3 - Sair"
  puts "============================"
  print "Escolha uma opção: "
  opcao = gets.chomp.to_i

  case opcao
  when 1
    print "Digite o tamanho da senha (padrão = 12): "
    tamanho = gets.chomp.to_i
    tamanho = 12 if tamanho <= 0

    print "Incluir números? (s/n): "
    usar_numeros = gets.chomp.downcase == "s"

    print "Incluir símbolos? (s/n): "
    usar_simbolos = gets.chomp.downcase == "s"

    print "Quantas senhas deseja gerar? "
    quantidade = gets.chomp.to_i
    quantidade = 1 if quantidade <= 0

    senhas = []
    quantidade.times do |i|
      senha = gerar_senha(tamanho, usar_numeros, usar_simbolos)
      puts "Senha #{i + 1}: #{senha}"
      senhas << senha
    end

    salvar_senhas(senhas)
    puts "\n✅ Senhas salvas em 'senhas.txt'!"

  when 2
    listar_senhas

  when 3
    puts "\n👋 Saindo do programa. Até logo!"
    break

  else
    puts "\n⚠️ Opção inválida! Tente novamente."
  end
end
