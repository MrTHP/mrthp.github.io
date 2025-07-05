sudo pacman -S --needed git base-devel \
  && git clone https://github.com/MrTHP/Architect.git ~/Architect \
  && cd ~/Architect \
  && chmod +x ./architect.sh \
  && ./architect.sh
